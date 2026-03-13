# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(LightspeedSandboxSimulator::Configuration)
    end
  end

  describe '.configure' do
    it 'yields configuration' do
      described_class.configure do |config|
        expect(config).to be_a(LightspeedSandboxSimulator::Configuration)
      end
    end
  end

  describe '.logger' do
    it 'returns a Logger' do
      expect(described_class.logger).to be_a(Logger)
    end
  end

  describe 'error classes' do
    it 'defines Error' do
      expect(LightspeedSandboxSimulator::Error.superclass).to eq(StandardError)
    end

    it 'defines ConfigurationError' do
      expect(LightspeedSandboxSimulator::ConfigurationError.superclass).to eq(LightspeedSandboxSimulator::Error)
    end

    it 'defines ApiError' do
      expect(LightspeedSandboxSimulator::ApiError.superclass).to eq(LightspeedSandboxSimulator::Error)
    end
  end
end
