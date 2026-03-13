# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Generators::EntityGenerator do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:generator) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  before do
    # Stub list endpoints (for find_by_name checks)
    stub_request(:get, "#{base_url}/menu/categories")
      .to_return(status: 200, body: { 'categories' => [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, "#{base_url}/menu/items")
      .to_return(status: 200, body: { 'items' => [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, "#{base_url}/payment-methods")
      .to_return(status: 200, body: { 'paymentMethods' => [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    # Stub create endpoints
    stub_request(:post, "#{base_url}/menu/categories")
      .to_return do
      { status: 201, body: { 'id' => rand(1..999), 'name' => 'Cat' }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end
    stub_request(:post, "#{base_url}/menu/items")
      .to_return do
      { status: 201, body: { 'id' => rand(1..999), 'name' => 'Item' }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end
    stub_request(:post, "#{base_url}/payment-methods")
      .to_return do
      { status: 201, body: { 'id' => rand(1..999), 'name' => 'Method' }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end
  end

  describe '#setup_all' do
    it 'sets up categories, items, and payment methods' do
      result = generator.setup_all
      expect(result[:categories]).not_to be_empty
      expect(result[:items]).not_to be_empty
      expect(result[:payment_methods]).not_to be_empty
    end
  end

  describe '#setup_categories' do
    it 'creates categories' do
      cats = generator.setup_categories
      expect(cats.size).to eq(5)
    end

    it 'skips existing categories' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200,
                   body: { 'categories' => [{ 'id' => 1, 'name' => 'Appetizers' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      cats = generator.setup_categories
      expect(cats.size).to eq(5)
    end
  end

  describe '#setup_items' do
    it 'creates items from loader' do
      categories = [{ 'id' => 1, 'name' => 'Appetizers' }, { 'id' => 2, 'name' => 'Entrees' }]
      items = generator.setup_items(categories)
      expect(items).not_to be_empty
    end

    it 'handles nil category (not in map)' do
      items = generator.setup_items([])
      expect(items).not_to be_empty
    end

    it 'skips existing items' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200,
                   body: { 'items' => [{ 'id' => 1, 'name' => 'Buffalo Wings' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      items = generator.setup_items([{ 'id' => 10, 'name' => 'Appetizers' }])
      expect(items).not_to be_empty
    end
  end

  describe '#setup_payment_methods' do
    it 'creates payment methods' do
      methods = generator.setup_payment_methods
      expect(methods.size).to eq(5)
    end

    it 'skips existing payment methods' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200,
                   body: { 'paymentMethods' => [{ 'id' => 1, 'name' => 'Cash' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      methods = generator.setup_payment_methods
      expect(methods.size).to eq(5)
    end

    it 'uses type from tender data' do
      gen = described_class.new(config: config, business_type: :restaurant)
      methods = gen.setup_payment_methods
      expect(methods).not_to be_empty
    end

    it 'handles nil result from create' do
      stub_request(:post, "#{base_url}/payment-methods")
        .to_return(status: 204, body: '', headers: {})

      methods = generator.setup_payment_methods
      expect(methods).to be_empty
    end
  end

  describe '#setup_categories with nil create result' do
    it 'excludes nil results' do
      stub_request(:post, "#{base_url}/menu/categories")
        .to_return(status: 204, body: '', headers: {})

      cats = generator.setup_categories
      expect(cats).to be_empty
    end
  end

  describe '#setup_items with nil create result' do
    it 'excludes nil results' do
      stub_request(:post, "#{base_url}/menu/items")
        .to_return(status: 204, body: '', headers: {})

      items = generator.setup_items([{ 'id' => 1, 'name' => 'Appetizers' }])
      expect(items).to be_empty
    end
  end

  describe 'build_category_map' do
    it 'skips entries with missing name or id' do
      categories = [{ 'name' => nil, 'id' => 1 }, { 'name' => 'Test', 'id' => nil }, { 'name' => 'Good', 'id' => 5 }]
      result = generator.send(:build_category_map, categories)
      expect(result).to eq({ 'Good' => 5 })
    end
  end
end
