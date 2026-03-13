# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Generators
    class OrderGenerator
      MEAL_PERIODS = {
        breakfast: { weight: 15, items_range: 1..3 },
        lunch: { weight: 30, items_range: 2..4 },
        happy_hour: { weight: 10, items_range: 2..4 },
        dinner: { weight: 35, items_range: 3..6 },
        late_night: { weight: 10, items_range: 1..3 }
      }.freeze

      DINING_OPTIONS = {
        breakfast: { eat_in: 40, takeaway: 50, delivery: 10 },
        lunch: { eat_in: 35, takeaway: 45, delivery: 20 },
        happy_hour: { eat_in: 80, takeaway: 15, delivery: 5 },
        dinner: { eat_in: 70, takeaway: 15, delivery: 15 },
        late_night: { eat_in: 50, takeaway: 30, delivery: 20 }
      }.freeze

      DAY_RANGES = {
        0 => 50..80,   # Sunday
        1 => 40..60,   # Monday
        2 => 40..60,   # Tuesday
        3 => 40..60,   # Wednesday
        4 => 40..60,   # Thursday
        5 => 70..100,  # Friday
        6 => 80..120   # Saturday
      }.freeze

      def initialize(config: nil, business_type: :restaurant, refund_percentage: 5)
        @config = config || LightspeedSandboxSimulator.configuration
        @business_type = business_type
        @refund_percentage = refund_percentage
        @manager = Services::Lightspeed::ServicesManager.new(config: @config)
      end

      def generate_today(count: nil)
        data = fetch_required_data
        count ||= daily_order_count
        orders = []

        distribution = distribute_across_periods(count)
        distribution.each do |period, period_count|
          period_count.times do
            order = generate_single_order(data, period: period)
            orders << order if order
          end
        end

        process_refunds(orders) if @refund_percentage.positive?
        generate_summary

        orders
      end

      def generate_realistic_day(multiplier: 1.0)
        count = (daily_order_count * multiplier).round
        generate_today(count: count)
      end

      def generate_rush(period: :dinner, count: 10)
        data = fetch_required_data
        orders = []

        count.times do
          order = generate_single_order(data, period: period)
          orders << order if order
        end

        orders
      end

      private

      def fetch_required_data
        items = @manager.menu.list_items
        items = items['items'] if items.is_a?(Hash) && items.key?('items')
        items = Array(items)
        raise Error, 'No items found. Run setup first.' if items.empty?

        payment_methods = @manager.payment_methods.list_payment_methods
        payment_methods = payment_methods['paymentMethods'] if payment_methods.is_a?(Hash)
        payment_methods = Array(payment_methods)
        raise Error, 'No payment methods found. Run setup first.' if payment_methods.empty?

        tenders_config = DataLoader.new(business_type: @business_type).load_tenders
        { items: items, payment_methods: payment_methods, tenders_config: tenders_config }
      end

      def generate_single_order(data, period: :lunch)
        return nil if data[:items].empty?

        dining_option = select_dining_option(period)
        order_items = select_items(data[:items], period)
        subtotal = order_items.sum { |i| (i[:unit_price] || 0) * (i[:quantity] || 1) }
        tax = (subtotal * @config.tax_rate / 100.0).round(2)
        discount = calculate_discount(subtotal)
        tip = calculate_tip(subtotal, dining_option)
        total = subtotal + tax - discount + tip

        order_type = dining_option == :eat_in ? :local : :to_go
        result = create_order(order_type, order_items)
        return nil unless result

        payment_method = select_payment_method(data[:payment_methods], data[:tenders_config])
        create_payment(result, total, tip, payment_method)
        persist_order(result, period, dining_option, tax, tip, discount, total, payment_method)

        result
      rescue ApiError => e
        LightspeedSandboxSimulator.logger.warn("Order failed: #{e.message}")
        nil
      end

      def create_order(order_type, items)
        if order_type == :local
          @manager.orders.create_local_order(items: items, table_number: rand(1..20))
        else
          @manager.orders.create_to_go_order(items: items)
        end
      end

      def create_payment(order_result, total, tip, payment_method)
        order_id = order_result['id'] || order_result['orderId']
        return unless order_id

        method_id = payment_method['id']
        return unless method_id

        @manager.payments.create_payment(
          order_id: order_id,
          amount: total,
          tip_amount: tip,
          payment_method_id: method_id
        )
      end

      def select_items(items, period)
        config = MEAL_PERIODS[period] || MEAL_PERIODS[:lunch]
        count = rand(config[:items_range])
        items.sample(count).map do |item|
          { item_id: item['id'], quantity: 1, unit_price: item['price'].to_f }
        end
      end

      def select_dining_option(period)
        weights = DINING_OPTIONS[period] || DINING_OPTIONS[:lunch]
        weighted_select(weights)
      end

      def select_payment_method(payment_methods, tenders_config)
        return payment_methods.first if tenders_config.empty?

        selected_name = weighted_select_tender(tenders_config)
        matched = payment_methods.find { |m| m['name']&.downcase == selected_name.downcase }
        matched || payment_methods.first
      end

      def weighted_select_tender(tenders_config)
        total = tenders_config.sum { |t| t['weight'].to_i }
        return tenders_config.first['name'] if total.zero?

        roll = rand(total)
        cumulative = 0
        tenders_config.each do |tender|
          cumulative += tender['weight'].to_i
          return tender['name'] if roll < cumulative
        end

        # :nocov:
        tenders_config.last&.dig('name')
        # :nocov:
      end

      def weighted_select(weights)
        total = weights.values.sum
        return weights.keys.last if total.zero?

        roll = rand(total)
        cumulative = 0
        weights.each do |key, weight|
          cumulative += weight
          return key if roll < cumulative
        end

        # :nocov:
        weights.keys.last
        # :nocov:
      end

      def calculate_discount(subtotal)
        return 0.0 if rand(100) >= 8

        percentage = rand(10..20) / 100.0
        (subtotal * percentage).round(2)
      end

      def calculate_tip(subtotal, dining_option)
        tip_config = case dining_option
                     when :eat_in then { chance: 70, min: 15, max: 25 }
                     when :takeaway then { chance: 20, min: 5, max: 15 }
                     when :delivery then { chance: 50, min: 10, max: 20 }
                     else { chance: 30, min: 10, max: 20 }
                     end

        return 0.0 if rand(100) >= tip_config[:chance]

        percentage = rand(tip_config[:min]..tip_config[:max]) / 100.0
        (subtotal * percentage).round(2)
      end

      def distribute_across_periods(total)
        distribution = {}

        MEAL_PERIODS.each do |period, config|
          count = (total * config[:weight] / 100.0).round
          distribution[period] = count
        end

        diff = total - distribution.values.sum
        distribution[:dinner] += diff

        distribution
      end

      def daily_order_count
        range = DAY_RANGES[Date.today.wday] || (40..60)
        rand(range)
      end

      def process_refunds(orders)
        return if orders.empty?

        refund_count = (orders.size * @refund_percentage / 100.0).ceil
        return if refund_count.zero?

        orders.sample(refund_count).each do |order|
          order_id = order['id']
          next unless order_id

          mark_order_refunded(order_id)
        end
      end

      def mark_order_refunded(order_id)
        return unless Database.connected?

        record = Models::SimulatedOrder.find_by(order_id: order_id.to_s)
        record&.update!(status: 'refunded')
      rescue StandardError => e
        LightspeedSandboxSimulator.logger.debug("Refund record failed: #{e.message}")
      end

      def persist_order(result, period, dining_option, tax, tip, discount, total, payment_method)
        return unless Database.connected?

        order = Models::SimulatedOrder.create!(
          order_id: (result['id'] || result['orderId']).to_s,
          order_type: result['orderType'] || 'local',
          meal_period: period.to_s,
          dining_option: dining_option.to_s,
          order_date: Date.today,
          total: (total * 100).round,
          tax_amount: (tax * 100).round,
          tip_amount: (tip * 100).round,
          discount_amount: (discount * 100).round,
          item_count: Array(result['items']).size
        )

        Models::SimulatedPayment.create!(
          simulated_order: order,
          payment_id: SecureRandom.uuid,
          tender_name: payment_method['name'].to_s,
          tender_type: payment_method['type'].to_s,
          amount: (total * 100).round,
          tip_amount: (tip * 100).round
        )
      rescue StandardError => e
        LightspeedSandboxSimulator.logger.debug("Persist failed: #{e.message}")
      end

      def generate_summary
        return unless Database.connected?

        Models::DailySummary.generate_for!(Date.today)
      rescue StandardError => e
        LightspeedSandboxSimulator.logger.debug("Summary generation failed: #{e.message}")
      end
    end
  end
end
