# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::Lightspeed::ServicesManager do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:manager) { described_class.new(config: config) }

  describe '#menu' do
    it 'returns a MenuService' do
      expect(manager.menu).to be_a(LightspeedSandboxSimulator::Services::Lightspeed::MenuService)
    end

    it 'memoizes the service' do
      expect(manager.menu).to equal(manager.menu)
    end
  end

  describe '#payment_methods' do
    it 'returns a PaymentMethodService' do
      expect(manager.payment_methods).to be_a(LightspeedSandboxSimulator::Services::Lightspeed::PaymentMethodService)
    end
  end

  describe '#orders' do
    it 'returns an OrderService' do
      expect(manager.orders).to be_a(LightspeedSandboxSimulator::Services::Lightspeed::OrderService)
    end
  end

  describe '#payments' do
    it 'returns a PaymentService' do
      expect(manager.payments).to be_a(LightspeedSandboxSimulator::Services::Lightspeed::PaymentService)
    end
  end

  describe '#business' do
    it 'returns a BusinessService' do
      expect(manager.business).to be_a(LightspeedSandboxSimulator::Services::Lightspeed::BusinessService)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent access' do
      threads = 5.times.map do
        Thread.new { manager.menu }
      end
      results = threads.map(&:value)
      expect(results.uniq.size).to eq(1)
    end
  end
end
