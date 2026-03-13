# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::Lightspeed::MenuService do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:service) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  describe '#list_categories' do
    it 'returns categories' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: { 'categories' => [{ 'id' => 1, 'name' => 'Drinks' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.list_categories
      expect(result['categories'].first['name']).to eq('Drinks')
    end
  end

  describe '#create_category' do
    it 'creates a category' do
      stub_request(:post, "#{base_url}/menu/categories")
        .to_return(status: 201, body: { 'id' => 1, 'name' => 'Appetizers' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_category(name: 'Appetizers')
      expect(result['name']).to eq('Appetizers')
    end

    it 'includes sort_order when provided' do
      stub_request(:post, "#{base_url}/menu/categories")
        .with { |req| JSON.parse(req.body)['sortOrder'] == 5 }
        .to_return(status: 201, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_category(name: 'Test', sort_order: 5)
    end
  end

  describe '#update_category' do
    it 'updates a category' do
      stub_request(:put, "#{base_url}/menu/categories/1")
        .to_return(status: 200, body: { 'id' => 1, 'name' => 'Updated' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.update_category(id: 1, name: 'Updated')
      expect(result['name']).to eq('Updated')
    end

    it 'includes sort_order when provided' do
      stub_request(:put, "#{base_url}/menu/categories/1")
        .to_return(status: 200, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.update_category(id: 1, name: 'Test', sort_order: 10)
    end
  end

  describe '#delete_category' do
    it 'deletes a category' do
      stub_request(:delete, "#{base_url}/menu/categories/1")
        .to_return(status: 204, body: '', headers: {})

      expect { service.delete_category(id: 1) }.not_to raise_error
    end
  end

  describe '#list_items' do
    it 'returns items' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: { 'items' => [{ 'id' => 1, 'name' => 'Coffee' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.list_items
      expect(result['items'].first['name']).to eq('Coffee')
    end
  end

  describe '#create_item' do
    it 'creates an item with all fields' do
      stub_request(:post, "#{base_url}/menu/items")
        .to_return(status: 201, body: { 'id' => 1, 'name' => 'Wings' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_item(
        name: 'Wings', price: 12.99, category_id: 1, sku: 'W001', description: 'Hot wings'
      )
      expect(result['name']).to eq('Wings')
    end

    it 'creates item with minimal fields' do
      stub_request(:post, "#{base_url}/menu/items")
        .to_return(status: 201, body: { 'id' => 2 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.create_item(name: 'Coffee', price: 4.50)
      expect(result['id']).to eq(2)
    end
  end

  describe '#update_item' do
    it 'updates an item' do
      stub_request(:put, "#{base_url}/menu/items/1")
        .to_return(status: 200, body: { 'id' => 1, 'name' => 'Updated' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.update_item(id: 1, name: 'Updated', price: 15.99, category_id: 2, taxable: false)
      expect(result['name']).to eq('Updated')
    end

    it 'updates with only name (no optional attrs)' do
      stub_request(:put, "#{base_url}/menu/items/2")
        .with do |req|
        body = JSON.parse(req.body)
        body.key?('name') && !body.key?('price')
      end
        .to_return(status: 200, body: { 'id' => 2 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.update_item(id: 2, name: 'Only Name')
    end

    it 'updates with no attributes' do
      stub_request(:put, "#{base_url}/menu/items/3")
        .with { |req| JSON.parse(req.body) == {} }
        .to_return(status: 200, body: { 'id' => 3 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.update_item(id: 3)
    end
  end

  describe '#delete_item' do
    it 'deletes an item' do
      stub_request(:delete, "#{base_url}/menu/items/1")
        .to_return(status: 204, body: '', headers: {})

      expect { service.delete_item(id: 1) }.not_to raise_error
    end
  end

  describe '#find_category_by_name' do
    it 'finds a category by name (case insensitive)' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: { 'categories' => [{ 'id' => 1, 'name' => 'Drinks' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.find_category_by_name('drinks')
      expect(result['id']).to eq(1)
    end

    it 'returns nil when not found' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: { 'categories' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_category_by_name('missing')).to be_nil
    end

    it 'handles non-array response' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: { 'error' => 'bad' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_category_by_name('test')).to be_nil
    end

    it 'handles nil Name values' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: { 'categories' => [{ 'id' => 1, 'name' => nil }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_category_by_name('test')).to be_nil
    end

    it 'handles array response (no categories key)' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: [{ 'id' => 1, 'name' => 'Drinks' }].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.find_category_by_name('drinks')
      expect(result['id']).to eq(1)
    end
  end

  describe '#find_item_by_name' do
    it 'finds an item by name' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: { 'items' => [{ 'id' => 1, 'name' => 'Coffee' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.find_item_by_name('coffee')
      expect(result['id']).to eq(1)
    end

    it 'returns nil for non-array response' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: { 'error' => 'bad' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_item_by_name('test')).to be_nil
    end

    it 'handles nil name values' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: { 'items' => [{ 'id' => 1, 'name' => nil }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_item_by_name('test')).to be_nil
    end

    it 'handles array response (no items key)' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: [{ 'id' => 1, 'name' => 'Coffee' }].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.find_item_by_name('coffee')
      expect(result['id']).to eq(1)
    end
  end
end
