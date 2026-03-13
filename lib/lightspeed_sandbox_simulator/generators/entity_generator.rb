# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Generators
    class EntityGenerator
      def initialize(config: nil, business_type: :restaurant)
        @config = config || LightspeedSandboxSimulator.configuration
        @business_type = business_type
        @loader = DataLoader.new(business_type: business_type)
        @manager = Services::Lightspeed::ServicesManager.new(config: @config)
      end

      def setup_all
        categories = setup_categories
        items = setup_items(categories)
        payment_methods = setup_payment_methods

        LightspeedSandboxSimulator.logger.info("Setup complete: #{categories.size} categories, " \
                                               "#{items.size} items, #{payment_methods.size} payment methods")

        { categories: categories, items: items, payment_methods: payment_methods }
      end

      def setup_categories
        data = @loader.load_categories
        created = []

        data.each do |cat|
          existing = @manager.menu.find_category_by_name(cat['name'])
          if existing
            created << existing
          else
            result = @manager.menu.create_category(name: cat['name'], sort_order: cat['sort_order'])
            created << result if result
          end
        end

        created
      end

      def setup_items(categories)
        data = @loader.load_items
        category_map = build_category_map(categories)
        created = []

        data.each do |item|
          existing = @manager.menu.find_item_by_name(item['name'])
          if existing
            created << existing
          else
            category_id = category_map[item['category']]
            result = @manager.menu.create_item(
              name: item['name'],
              price: item['price'],
              category_id: category_id,
              sku: item['sku']
            )
            created << result if result
          end
        end

        created
      end

      def setup_payment_methods
        data = @loader.load_tenders
        created = []

        data.each do |tender|
          existing = @manager.payment_methods.find_payment_method_by_name(tender['name'])
          if existing
            created << existing
          else
            result = @manager.payment_methods.create_payment_method(
              name: tender['name'],
              type: tender.fetch('type', 'OTHER')
            )
            created << result if result
          end
        end

        created
      end

      private

      def build_category_map(categories)
        categories.each_with_object({}) do |cat, map|
          name = cat['name'] || cat[:name]
          id = cat['id'] || cat[:id]
          map[name] = id if name && id
        end
      end
    end
  end
end
