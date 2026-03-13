# frozen_string_literal: true

require 'json'

module LightspeedSandboxSimulator
  module Generators
    class DataLoader
      DATA_DIR = File.expand_path('../data', __dir__)
      BUSINESS_TYPES = %i[restaurant cafe_bakery bar_nightclub retail_general].freeze

      attr_reader :business_type

      def initialize(business_type: :restaurant)
        @business_type = business_type
      end

      def load_categories
        if Database.connected?
          bt = Models::BusinessType.find_by(key: business_type.to_s)
          return load_categories_from_db(bt) if bt
        end

        data = load_from_json('categories')
        data.fetch('categories', [])
      end

      def load_items
        if Database.connected?
          bt = Models::BusinessType.find_by(key: business_type.to_s)
          return load_items_from_db(bt) if bt
        end

        data = load_from_json('items')
        data.fetch('items', [])
      end

      def load_tenders
        data = load_from_json('tenders')
        data.fetch('tenders', [])
      end

      def load_items_by_category
        load_items.group_by { |i| i['category'] }
      end

      private

      def load_categories_from_db(btype)
        btype.categories.order(:sort_order).map do |cat|
          { 'name' => cat.name, 'sort_order' => cat.sort_order, 'description' => cat.description }
        end
      end

      def load_items_from_db(btype)
        btype.items.includes(:category).map do |item|
          {
            'name' => item.name,
            'price' => item.price / 100.0,
            'category' => item.category&.name,
            'sku' => item.sku
          }
        end
      end

      def load_from_json(type)
        path = File.join(DATA_DIR, business_type.to_s, "#{type}.json")
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        {}
      end
    end
  end
end
