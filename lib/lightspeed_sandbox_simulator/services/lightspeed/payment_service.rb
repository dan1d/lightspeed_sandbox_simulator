# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Services
    module Lightspeed
      class PaymentService < BaseService
        def create_payment(order_id:, amount:, payment_method_id:, tip_amount: 0, staff_id: nil)
          payload = {
            orderId: order_id,
            paymentAmount: amount,
            tipAmount: tip_amount,
            paymentMethodId: payment_method_id
          }
          payload[:staffId] = staff_id if staff_id
          request(:post, "#{API_PREFIX}/businesses/#{config.business_id}/payments",
                  payload: payload, resource_type: 'Payment')
        end

        def fetch_payments(start_date:, end_date:, cursor: nil, limit: 100)
          params = { startDate: format_date(start_date), endDate: format_date(end_date), limit: limit }
          params[:cursor] = cursor if cursor
          request(:get, endpoint('payments'), params: params)
        end

        def fetch_all_payments(start_date:, end_date:)
          all_payments = []
          cursor = nil

          loop do
            result = fetch_payments(start_date: start_date, end_date: end_date, cursor: cursor)
            return all_payments unless result.is_a?(Hash)

            payments = result['payments'] || []
            all_payments.concat(payments)

            cursor = result['cursor']
            break if cursor.nil? || cursor.to_s.empty? || payments.empty?
          end

          all_payments
        end

        private

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
