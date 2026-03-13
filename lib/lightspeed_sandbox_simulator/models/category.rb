# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class Category < ActiveRecord::Base
      self.table_name = 'categories'

      belongs_to :business_type
      has_many :items, dependent: :destroy
    end
  end
end
