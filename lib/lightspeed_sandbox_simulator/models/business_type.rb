# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class BusinessType < ActiveRecord::Base
      self.table_name = 'business_types'

      has_many :categories, dependent: :destroy
      has_many :items, through: :categories
    end
  end
end
