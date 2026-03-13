# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class DailySummary < ActiveRecord::Base
      self.table_name = 'daily_summaries'

      class << self
        def generate_for!(date)
          orders = SimulatedOrder.for_date(date)
          paid = orders.paid
          refunded = orders.refunded

          payments = SimulatedPayment.successful
                                     .joins(:simulated_order)
                                     .where(simulated_orders: { order_date: date })

          breakdown = build_breakdown(paid, payments)

          summary = find_or_initialize_by(summary_date: date)
          summary.update!(
            order_count: paid.count,
            payment_count: payments.count,
            refund_count: refunded.count,
            total_revenue: paid.sum(:total),
            total_tax: paid.sum(:tax_amount),
            total_tips: paid.sum(:tip_amount),
            total_discounts: paid.sum(:discount_amount),
            breakdown: breakdown
          )
          summary
        end

        def build_breakdown(orders, payments)
          {
            by_meal_period: orders.group(:meal_period).sum(:total),
            by_dining_option: orders.group(:dining_option).sum(:total),
            by_tender: payments.group(:tender_name).sum(:amount)
          }
        end
      end
    end
  end
end
