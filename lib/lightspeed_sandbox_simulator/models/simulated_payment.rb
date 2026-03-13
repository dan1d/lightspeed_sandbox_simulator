# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class SimulatedPayment < ActiveRecord::Base
      self.table_name = 'simulated_payments'

      belongs_to :simulated_order

      scope :successful, -> { where(status: 'successful') }
    end
  end
end
