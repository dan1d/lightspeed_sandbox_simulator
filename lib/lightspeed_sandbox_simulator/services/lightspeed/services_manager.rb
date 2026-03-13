# frozen_string_literal: true

require 'concurrent'

module LightspeedSandboxSimulator
  module Services
    module Lightspeed
      class ServicesManager
        def initialize(config: nil)
          @config = config || LightspeedSandboxSimulator.configuration
          @mutex = Mutex.new
        end

        def menu
          thread_safe_memoize(:@menu) { MenuService.new(config: @config) }
        end

        def payment_methods
          thread_safe_memoize(:@payment_methods) { PaymentMethodService.new(config: @config) }
        end

        def orders
          thread_safe_memoize(:@orders) { OrderService.new(config: @config) }
        end

        def payments
          thread_safe_memoize(:@payments) { PaymentService.new(config: @config) }
        end

        def business
          thread_safe_memoize(:@business) { BusinessService.new(config: @config) }
        end

        private

        def thread_safe_memoize(ivar_name)
          value = instance_variable_get(ivar_name)
          return value if value

          @mutex.synchronize do
            # :nocov:
            value = instance_variable_get(ivar_name)
            return value if value
            # :nocov:

            value = yield
            instance_variable_set(ivar_name, value)
            value
          end
        end
      end
    end
  end
end
