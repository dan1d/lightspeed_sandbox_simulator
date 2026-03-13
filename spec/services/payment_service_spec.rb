# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::Lightspeed::PaymentService do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:service) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  describe '#create_payment' do
    it 'creates a payment' do
      stub_request(:post, "#{base_url}/payments")
        .to_return(status: 201, body: { 'id' => 500 }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_payment(order_id: 100, amount: 25.50, payment_method_id: 1)
      expect(result['id']).to eq(500)
    end

    it 'includes tip_amount and staff_id' do
      stub_request(:post, "#{base_url}/payments")
        .with do |req|
          body = JSON.parse(req.body)
          (body['tipAmount'] - 5.0).abs < 0.001 && body['staffId'] == 42
        end
        .to_return(status: 201, body: { 'id' => 501 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_payment(order_id: 100, amount: 25.50, payment_method_id: 1, tip_amount: 5.0, staff_id: 42)
    end
  end

  describe '#fetch_payments' do
    it 'fetches payments by date range' do
      stub_request(:get, "#{base_url}/payments?endDate=2026-03-13&limit=100&startDate=2026-03-13")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 1 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_payments(start_date: Date.new(2026, 3, 13), end_date: Date.new(2026, 3, 13))
      expect(result['payments'].size).to eq(1)
    end

    it 'includes cursor when provided' do
      stub_request(:get, "#{base_url}/payments?cursor=abc&endDate=2026-03-13&limit=100&startDate=2026-03-13")
        .to_return(status: 200, body: { 'payments' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.fetch_payments(start_date: Date.new(2026, 3, 13), end_date: Date.new(2026, 3, 13), cursor: 'abc')
    end

    it 'handles Time objects' do
      stub_request(:get, /payments/)
        .to_return(status: 200, body: { 'payments' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.fetch_payments(start_date: Time.now, end_date: Time.now)
    end

    it 'handles string dates' do
      stub_request(:get, /payments/)
        .to_return(status: 200, body: { 'payments' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.fetch_payments(start_date: '2026-03-13', end_date: '2026-03-13')
    end
  end

  describe '#fetch_all_payments' do
    it 'paginates through all payments' do
      today = Date.today.iso8601
      stub_request(:get, "#{base_url}/payments?endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 1 }], 'cursor' => 'c1' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{base_url}/payments?cursor=c1&endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 2 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_all_payments(start_date: Date.today, end_date: Date.today)
      expect(result.size).to eq(2)
    end

    it 'handles non-hash response' do
      today = Date.today.iso8601
      stub_request(:get, "#{base_url}/payments?endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_all_payments(start_date: Date.today, end_date: Date.today)
      expect(result).to eq([])
    end

    it 'stops on empty cursor' do
      today = Date.today.iso8601
      stub_request(:get, "#{base_url}/payments?endDate=#{today}&limit=100&startDate=#{today}")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 1 }], 'cursor' => '' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_all_payments(start_date: Date.today, end_date: Date.today)
      expect(result.size).to eq(1)
    end
  end
end
