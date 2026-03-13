# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::Lightspeed::PaymentMethodService do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:service) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  describe '#list_payment_methods' do
    it 'returns payment methods' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: { 'paymentMethods' => [{ 'id' => 1, 'name' => 'Cash' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.list_payment_methods
      expect(result['paymentMethods'].first['name']).to eq('Cash')
    end
  end

  describe '#create_payment_method' do
    it 'creates a payment method' do
      stub_request(:post, "#{base_url}/payment-methods")
        .to_return(status: 201, body: { 'id' => 1, 'name' => 'Cash', 'type' => 'CASH' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.create_payment_method(name: 'Cash', type: 'CASH')
      expect(result['name']).to eq('Cash')
    end

    it 'defaults type to OTHER' do
      stub_request(:post, "#{base_url}/payment-methods")
        .with { |req| JSON.parse(req.body)['type'] == 'OTHER' }
        .to_return(status: 201, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.create_payment_method(name: 'Custom')
    end
  end

  describe '#delete_payment_method' do
    it 'deletes a payment method' do
      stub_request(:delete, "#{base_url}/payment-methods/1")
        .to_return(status: 204, body: '', headers: {})

      expect { service.delete_payment_method(id: 1) }.not_to raise_error
    end
  end

  describe '#find_payment_method_by_name' do
    it 'finds by name (case insensitive)' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: { 'paymentMethods' => [{ 'id' => 1, 'name' => 'Cash' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.find_payment_method_by_name('cash')
      expect(result['id']).to eq(1)
    end

    it 'returns nil when not found' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: { 'paymentMethods' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_payment_method_by_name('missing')).to be_nil
    end

    it 'handles non-array response' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: { 'error' => 'bad' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_payment_method_by_name('test')).to be_nil
    end

    it 'handles nil name values' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: { 'paymentMethods' => [{ 'id' => 1, 'name' => nil }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.find_payment_method_by_name('test')).to be_nil
    end
  end
end
