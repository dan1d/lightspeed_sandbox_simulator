# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Services
    module Lightspeed
      class PaymentMethodService < BaseService
        def list_payment_methods
          request(:get, endpoint('payment-methods'))
        end

        def create_payment_method(name:, type: 'OTHER')
          payload = { name: name, type: type }
          request(:post, endpoint('payment-methods'), payload: payload)
        end

        def delete_payment_method(id:)
          request(:delete, endpoint("payment-methods/#{id}"))
        end

        def find_payment_method_by_name(name)
          methods = list_payment_methods
          methods = methods['paymentMethods'] if methods.is_a?(Hash) && methods.key?('paymentMethods')
          return nil unless methods.is_a?(Array)

          methods.find { |m| m['name']&.downcase == name.downcase }
        end
      end
    end
  end
end
