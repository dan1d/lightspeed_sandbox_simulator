# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::Lightspeed::OrderService do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:service) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  describe 'ORDER_TYPES' do
    it 'defines local and to_go' do
      expect(described_class::ORDER_TYPES).to include(local: 'local', to_go: 'toGo')
    end
  end

  describe '#create_local_order' do
    it 'creates a local (dine-in) order' do
      stub_request(:post, "#{base_url}/orders/local")
        .to_return(status: 201, body: { 'id' => 100, 'orderType' => 'local' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_local_order(items: [{ item_id: 1, quantity: 2 }])
      expect(result['id']).to eq(100)
    end

    it 'includes table_number and covers' do
      stub_request(:post, "#{base_url}/orders/local")
        .with do |req|
        body = JSON.parse(req.body)
        body['tableNumber'] == 5 && body['covers'] == 4
      end
        .to_return(status: 201, body: { 'id' => 101 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_local_order(items: [{ item_id: 1, quantity: 1 }], table_number: 5, covers: 4)
    end
  end

  describe '#create_to_go_order' do
    it 'creates a to-go order' do
      stub_request(:post, "#{base_url}/orders/toGo")
        .to_return(status: 201, body: { 'id' => 200, 'orderType' => 'toGo' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_to_go_order(items: [{ item_id: 1, quantity: 1 }])
      expect(result['id']).to eq(200)
    end

    it 'includes customer_name' do
      stub_request(:post, "#{base_url}/orders/toGo")
        .with { |req| JSON.parse(req.body)['customerName'] == 'John' }
        .to_return(status: 201, body: { 'id' => 201 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_to_go_order(items: [{ item_id: 1, quantity: 1 }], customer_name: 'John')
    end
  end

  describe '#fetch_orders' do
    it 'fetches orders by date range' do
      stub_request(:get, "#{base_url}/orders?endDate=2026-03-13&limit=100&startDate=2026-03-13")
        .to_return(status: 200, body: { 'orders' => [{ 'id' => 1 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_orders(start_date: Date.new(2026, 3, 13), end_date: Date.new(2026, 3, 13))
      expect(result['orders'].size).to eq(1)
    end

    it 'includes cursor when provided' do
      stub_request(:get, "#{base_url}/orders?cursor=abc&endDate=2026-03-13&limit=100&startDate=2026-03-13")
        .to_return(status: 200, body: { 'orders' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.fetch_orders(start_date: Date.new(2026, 3, 13), end_date: Date.new(2026, 3, 13), cursor: 'abc')
    end

    it 'handles Time objects for dates' do
      stub_request(:get, /orders/)
        .to_return(status: 200, body: { 'orders' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.fetch_orders(start_date: Time.now, end_date: Time.now)
    end

    it 'handles string dates' do
      stub_request(:get, /orders/)
        .to_return(status: 200, body: { 'orders' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.fetch_orders(start_date: '2026-03-13', end_date: '2026-03-13')
    end
  end

  describe '#fetch_all_orders' do
    it 'paginates through all orders' do
      today = Date.today.iso8601
      stub_request(:get, "#{base_url}/orders?endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: { 'orders' => [{ 'id' => 1 }], 'cursor' => 'c1' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{base_url}/orders?cursor=c1&endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: { 'orders' => [{ 'id' => 2 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_all_orders(start_date: Date.today, end_date: Date.today)
      expect(result.size).to eq(2)
    end

    it 'handles non-hash response' do
      today = Date.today.iso8601
      stub_request(:get, "#{base_url}/orders?endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_all_orders(start_date: Date.today, end_date: Date.today)
      expect(result).to eq([])
    end

    it 'stops on empty cursor' do
      today = Date.today.iso8601
      stub_request(:get, "#{base_url}/orders?endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: { 'orders' => [{ 'id' => 1 }], 'cursor' => '' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_all_orders(start_date: Date.today, end_date: Date.today)
      expect(result.size).to eq(1)
    end
  end

  describe 'item payload building' do
    it 'includes optional fields' do
      stub_request(:post, "#{base_url}/orders/local")
        .with do |req|
          body = JSON.parse(req.body)
          item = body['items'].first
          (item['unitPrice'] - 9.99).abs < 0.001 &&
            (item['discountAmount'] - 2.0).abs < 0.001 &&
            item['notes'] == 'Extra sauce'
        end
        .to_return(status: 201, body: { 'id' => 300 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_local_order(items: [
                                   { item_id: 1, quantity: 2, unit_price: 9.99, discount: 2.0, notes: 'Extra sauce' }
                                 ])
    end

    it 'omits zero discount' do
      stub_request(:post, "#{base_url}/orders/local")
        .with do |req|
          body = JSON.parse(req.body)
          !body['items'].first.key?('discountAmount')
        end
        .to_return(status: 201, body: { 'id' => 301 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_local_order(items: [{ item_id: 1, quantity: 1, discount: 0.0 }])
    end
  end
end
