# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Services
    module Lightspeed
      class BusinessService < BaseService
        def fetch_business
          request(:get, "#{API_PREFIX}/businesses/#{config.business_id}")
        end

        def list_tax_rates
          request(:get, endpoint('tax-rates'))
        end

        def list_floors
          request(:get, endpoint('floorplans'))
        end
      end
    end
  end
end
