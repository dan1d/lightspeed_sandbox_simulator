# frozen_string_literal: true

module LightspeedSandboxSimulator
  module Services
    module Lightspeed
      class MenuService < BaseService
        def list_categories
          request(:get, endpoint('menu/categories'))
        end

        def create_category(name:, sort_order: nil)
          payload = { name: name }
          payload[:sortOrder] = sort_order if sort_order
          request(:post, endpoint('menu/categories'), payload: payload)
        end

        def update_category(id:, name:, sort_order: nil)
          payload = { name: name }
          payload[:sortOrder] = sort_order if sort_order
          request(:put, endpoint("menu/categories/#{id}"), payload: payload)
        end

        def delete_category(id:)
          request(:delete, endpoint("menu/categories/#{id}"))
        end

        def list_items
          request(:get, endpoint('menu/items'))
        end

        def create_item(name:, price:, category_id: nil, taxable: true, sku: nil, description: nil)
          payload = { name: name, price: price, taxable: taxable }
          payload[:categoryId] = category_id if category_id
          payload[:sku] = sku if sku
          payload[:description] = description if description
          request(:post, endpoint('menu/items'), payload: payload)
        end

        def update_item(id:, **attributes)
          payload = {}
          payload[:name] = attributes[:name] if attributes.key?(:name)
          payload[:price] = attributes[:price] if attributes.key?(:price)
          payload[:categoryId] = attributes[:category_id] if attributes.key?(:category_id)
          payload[:taxable] = attributes[:taxable] if attributes.key?(:taxable)
          request(:put, endpoint("menu/items/#{id}"), payload: payload)
        end

        def delete_item(id:)
          request(:delete, endpoint("menu/items/#{id}"))
        end

        def find_category_by_name(name)
          categories = list_categories
          categories = categories['categories'] if categories.is_a?(Hash) && categories.key?('categories')
          return nil unless categories.is_a?(Array)

          categories.find { |c| c['name']&.downcase == name.downcase }
        end

        def find_item_by_name(name)
          items = list_items
          items = items['items'] if items.is_a?(Hash) && items.key?('items')
          return nil unless items.is_a?(Array)

          items.find { |i| i['name']&.downcase == name.downcase }
        end
      end
    end
  end
end
