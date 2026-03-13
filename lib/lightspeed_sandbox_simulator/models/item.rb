# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Models
    class Item < ActiveRecord::Base
      self.table_name = 'items'

      belongs_to :category
    end
  end
end
