# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class SimulatedOrder < ActiveRecord::Base
      self.table_name = 'simulated_orders'

      has_many :simulated_payments, dependent: :destroy

      scope :for_date, ->(date) { where(order_date: date) }
      scope :paid, -> { where(status: 'paid') }
      scope :refunded, -> { where(status: 'refunded') }
    end
  end
end
