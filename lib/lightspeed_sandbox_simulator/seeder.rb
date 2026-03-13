# frozen_string_literal: true

require 'factory_bot'

module LightspeedSandboxSimulator
  class Seeder
    TYPES = {
      restaurant: { name: 'Restaurant', industry: 'food' },
      cafe_bakery: { name: 'Cafe & Bakery', industry: 'food' },
      bar_nightclub: { name: 'Bar & Nightclub', industry: 'food' },
      retail_general: { name: 'Retail General', industry: 'retail' }
    }.freeze

    class << self
      def seed!(business_type: :restaurant)
        validate_business_type!(business_type)

        types = business_type == :all ? TYPES.keys : [business_type]
        result = {}

        types.each do |type|
          result[type] = seed_type(type)
        end

        result
      end

      private

      def validate_business_type!(type)
        return if type == :all || TYPES.key?(type)

        raise Error, "Unknown business type: #{type}. Valid: #{TYPES.keys.join(', ')}"
      end

      def seed_type(type)
        bt = find_or_create_business_type(type)
        loader = Generators::DataLoader.new(business_type: type)

        categories = seed_categories(bt, loader)
        items = seed_items(categories, loader)

        { business_type: bt, categories: categories.size, items: items.size }
      end

      def find_or_create_business_type(type)
        config = TYPES[type]
        Models::BusinessType.find_or_create_by!(key: type.to_s) do |bt|
          bt.name = config[:name]
          bt.industry = config[:industry]
        end
      end

      def seed_categories(btype, loader)
        loader.load_categories.map do |cat|
          btype.categories.find_or_create_by!(name: cat['name']) do |c|
            c.sort_order = cat['sort_order'] || 0
            c.description = cat['description']
          end
        end
      end

      def seed_items(categories, loader)
        category_map = categories.index_by(&:name)

        loader.load_items.map do |item_data|
          category = category_map[item_data['category']]
          next unless category

          category.items.find_or_create_by!(name: item_data['name']) do |i|
            i.price = (item_data['price'].to_f * 100).round
            i.sku = item_data['sku']
            i.taxable = item_data.fetch('taxable', true)
          end
        end.compact
      end
    end
  end
end
