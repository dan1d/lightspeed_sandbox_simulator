# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class ApiRequest < ActiveRecord::Base
      self.table_name = 'api_requests'
    end
  end
end
