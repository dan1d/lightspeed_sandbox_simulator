# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Services
    module Lightspeed
      class OrderService < BaseService
        ORDER_TYPES = { local: 'local', to_go: 'toGo' }.freeze

        def create_local_order(items:, table_number: nil, covers: nil)
          payload = build_order_payload(items)
          payload[:tableNumber] = table_number if table_number
          payload[:covers] = covers if covers
          request(:post, "#{API_PREFIX}/businesses/#{config.business_id}/orders/local",
                  payload: payload, resource_type: 'Order')
        end

        def create_to_go_order(items:, customer_name: nil)
          payload = build_order_payload(items)
          payload[:customerName] = customer_name if customer_name
          request(:post, "#{API_PREFIX}/businesses/#{config.business_id}/orders/toGo",
                  payload: payload, resource_type: 'Order')
        end

        def fetch_orders(start_date:, end_date:, cursor: nil, limit: 100)
          params = { startDate: format_date(start_date), endDate: format_date(end_date), limit: limit }
          params[:cursor] = cursor if cursor
          request(:get, endpoint('orders'), params: params)
        end

        def fetch_all_orders(start_date:, end_date:)
          all_orders = []
          cursor = nil

          loop do
            result = fetch_orders(start_date: start_date, end_date: end_date, cursor: cursor)
            return all_orders unless result.is_a?(Hash)

            orders = result['orders'] || []
            all_orders.concat(orders)

            cursor = result['cursor']
            break if cursor.nil? || cursor.to_s.empty? || orders.empty?
          end

          all_orders
        end

        private

        def build_order_payload(items)
          {
            items: items.map { |item| build_item_payload(item) }
          }
        end

        def build_item_payload(item)
          entry = { itemId: item[:item_id], quantity: item[:quantity] || 1 }
          entry[:unitPrice] = item[:unit_price] if item[:unit_price]
          entry[:discountAmount] = item[:discount] if item[:discount]&.positive?
          entry[:notes] = item[:notes] if item[:notes]
          entry
        end

        def format_date(value)
          case value
          when Date then value.iso8601
          when Time then value.to_date.iso8601
          else value.to_s
          end
        end
      end
    end
  end
end
