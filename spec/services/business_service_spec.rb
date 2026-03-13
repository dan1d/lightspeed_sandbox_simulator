# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::Lightspeed::BusinessService do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:service) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  describe '#fetch_business' do
    it 'returns business info' do
      stub_request(:get, base_url.to_s)
        .to_return(status: 200, body: { 'id' => 12_345, 'name' => 'Test Biz' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.fetch_business
      expect(result['name']).to eq('Test Biz')
    end
  end

  describe '#list_tax_rates' do
    it 'returns tax rates' do
      stub_request(:get, "#{base_url}/tax-rates")
        .to_return(status: 200, body: { 'taxRates' => [{ 'id' => 1, 'rate' => 20.0 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.list_tax_rates
      expect(result['taxRates'].first['rate']).to eq(20.0)
    end
  end

  describe '#list_floors' do
    it 'returns floor plans' do
      stub_request(:get, "#{base_url}/floorplans")
        .to_return(status: 200, body: { 'floorplans' => [{ 'id' => 1 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.list_floors
      expect(result['floorplans'].size).to eq(1)
    end
  end
end
