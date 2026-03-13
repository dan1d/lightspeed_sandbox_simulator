# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Configuration do
  let(:config) do
    c = described_class.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end

  describe '#initialize' do
    it 'sets default base_url' do
      expect(config.base_url).to eq('https://api.lsk.lightspeed.app')
    end

    it 'sets default auth_url' do
      expect(config.auth_url).to eq('https://cloud.lsk.lightspeed.app')
    end

    it 'sets default tax_rate' do
      expect(config.tax_rate).to eq(20.0)
    end

    it 'sets default merchant_timezone' do
      expect(config.merchant_timezone).to eq('America/New_York')
    end
  end

  describe '#initialize with .env file' do
    it 'loads .env when present' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('.env').and_return(true)
      allow(Dotenv).to receive(:load)

      described_class.new
      expect(Dotenv).to have_received(:load)
    end
  end

  describe '#validate!' do
    it 'passes with valid config' do
      expect { config.validate! }.not_to raise_error
    end

    it 'raises when access_token is nil' do
      config.access_token = nil
      expect { config.validate! }.to raise_error(LightspeedSandboxSimulator::ConfigurationError, /ACCESS_TOKEN/)
    end

    it 'raises when access_token is empty' do
      config.access_token = ''
      expect { config.validate! }.to raise_error(LightspeedSandboxSimulator::ConfigurationError, /ACCESS_TOKEN/)
    end

    it 'raises when business_id is nil' do
      config.business_id = nil
      expect { config.validate! }.to raise_error(LightspeedSandboxSimulator::ConfigurationError, /BUSINESS_ID/)
    end

    it 'raises when business_id is empty' do
      config.business_id = ''
      expect { config.validate! }.to raise_error(LightspeedSandboxSimulator::ConfigurationError, /BUSINESS_ID/)
    end
  end

  describe '#logger' do
    it 'returns a Logger' do
      expect(config.logger).to be_a(Logger)
    end

    it 'memoizes the logger' do
      expect(config.logger).to equal(config.logger)
    end

    it 'formats log output' do
      output = StringIO.new
      config.logger = Logger.new(output)
      config.logger.info('test')
      expect(output.string).to include('test')
    end
  end

  describe '#auth_token' do
    it 'returns the access_token' do
      expect(config.auth_token).to eq('test-token')
    end
  end

  describe '#merchant_time_now' do
    it 'returns time in merchant timezone' do
      config.merchant_timezone = 'America/New_York'
      time = config.merchant_time_now
      expect(time).to be_a(Time)
    end

    it 'falls back to local time for invalid timezone' do
      config.merchant_timezone = 'Invalid/Timezone'
      time = config.merchant_time_now
      expect(time).to be_a(Time)
    end
  end

  describe '.load_from_merchants_file' do
    it 'returns nil for missing file' do
      expect(described_class.load_from_merchants_file('nonexistent.json')).to be_nil
    end

    it 'parses array format' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('[{"LIGHTSPEED_BUSINESS_ID": "1"}]')

      result = described_class.load_from_merchants_file('test.json')
      expect(result).to be_an(Array)
    end

    it 'parses object format with merchants key' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('{"merchants": [{"LIGHTSPEED_BUSINESS_ID": "1"}]}')

      result = described_class.load_from_merchants_file('test.json')
      expect(result).to be_an(Array)
    end

    it 'returns empty array for object without merchants key' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('{"other": "data"}')

      result = described_class.load_from_merchants_file('test.json')
      expect(result).to eq([])
    end

    it 'returns nil for parse errors' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('invalid json')

      expect(described_class.load_from_merchants_file('test.json')).to be_nil
    end

    it 'returns nil for non-array non-hash data' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('"just a string"')

      expect(described_class.load_from_merchants_file('test.json')).to be_nil
    end
  end

  describe '.load_merchant' do
    let(:merchants) do
      [
        { 'LIGHTSPEED_ACCESS_TOKEN' => 'tok1', 'LIGHTSPEED_BUSINESS_ID' => 'b1',
          'LIGHTSPEED_DEVICE_NAME' => 'Device A', 'LIGHTSPEED_CLIENT_ID' => 'cid1',
          'LIGHTSPEED_CLIENT_SECRET' => 'cs1', 'LIGHTSPEED_REFRESH_TOKEN' => 'rt1' },
        { 'LIGHTSPEED_ACCESS_TOKEN' => 'tok2', 'LIGHTSPEED_BUSINESS_ID' => 'b2',
          'LIGHTSPEED_DEVICE_NAME' => 'Device B' }
      ]
    end

    before do
      allow(described_class).to receive(:load_from_merchants_file).and_return(merchants)
    end

    it 'loads by index' do
      config = described_class.load_merchant(index: 1)
      expect(config.business_id).to eq('b2')
    end

    it 'loads by name' do
      config = described_class.load_merchant(name: 'device a')
      expect(config.access_token).to eq('tok1')
      expect(config.client_id).to eq('cid1')
      expect(config.client_secret).to eq('cs1')
      expect(config.refresh_token).to eq('rt1')
    end

    it 'loads first by default' do
      config = described_class.load_merchant
      expect(config.business_id).to eq('b1')
    end

    it 'returns nil when not found' do
      config = described_class.load_merchant(name: 'nonexistent')
      expect(config).to be_nil
    end

    it 'returns nil when merchants file is empty' do
      allow(described_class).to receive(:load_from_merchants_file).and_return(nil)
      expect(described_class.load_merchant).to be_nil
    end

    it 'returns nil when merchants array is empty' do
      allow(described_class).to receive(:load_from_merchants_file).and_return([])
      expect(described_class.load_merchant).to be_nil
    end

    it 'handles nil LIGHTSPEED_DEVICE_NAME when searching by name' do
      merchants_no_name = [{ 'LIGHTSPEED_ACCESS_TOKEN' => 'tok1', 'LIGHTSPEED_BUSINESS_ID' => 'b1' }]
      allow(described_class).to receive(:load_from_merchants_file).and_return(merchants_no_name)

      config = described_class.load_merchant(name: 'test')
      expect(config).to be_nil
    end

    it 'skips empty values' do
      merchants_with_empty = [{ 'LIGHTSPEED_ACCESS_TOKEN' => '', 'LIGHTSPEED_BUSINESS_ID' => 'b1' }]
      allow(described_class).to receive(:load_from_merchants_file).and_return(merchants_with_empty)

      config = described_class.load_merchant
      expect(config.business_id).to eq('b1')
    end
  end

  describe '.available_merchants' do
    it 'returns formatted merchant list' do
      merchants = [{ 'LIGHTSPEED_DEVICE_NAME' => 'Dev1', 'LIGHTSPEED_BUSINESS_ID' => 'b1' }]
      allow(described_class).to receive(:load_from_merchants_file).and_return(merchants)

      result = described_class.available_merchants
      expect(result.first).to include(index: 0, name: 'Dev1', business_id: 'b1')
    end

    it 'returns empty array when no merchants' do
      allow(described_class).to receive(:load_from_merchants_file).and_return(nil)
      expect(described_class.available_merchants).to eq([])
    end
  end

  describe '.database_url_from_file' do
    it 'returns URL from .env.json' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('.env.json').and_return(true)
      allow(File).to receive(:read).with('.env.json').and_return('{"DATABASE_URL": "postgres://localhost/db"}')

      expect(described_class.database_url_from_file).to eq('postgres://localhost/db')
    end

    it 'returns nil for missing file' do
      expect(described_class.database_url_from_file('nonexistent.json')).to be_nil
    end

    it 'returns nil for array format' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('[]')

      expect(described_class.database_url_from_file('test.json')).to be_nil
    end

    it 'returns nil for parse errors' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('test.json').and_return(true)
      allow(File).to receive(:read).with('test.json').and_return('not json')

      expect(described_class.database_url_from_file('test.json')).to be_nil
    end
  end

  describe 'private #normalize_url' do
    it 'strips trailing slash' do
      c = described_class.new
      c.base_url = 'https://api.lsk.lightspeed.app/'
      # normalize_url is called in initialize, test via base_url after explicit set
      expect(c.send(:normalize_url, 'https://example.com/')).to eq('https://example.com')
    end

    it 'handles nil' do
      c = described_class.new
      expect(c.send(:normalize_url, nil)).to be_nil
    end
  end

  describe 'private #parse_log_level' do
    let(:instance) { described_class.new }

    %w[DEBUG INFO WARN ERROR FATAL].each do |level|
      it "parses #{level}" do
        result = instance.send(:parse_log_level, level)
        expect(result).to eq(Logger.const_get(level))
      end
    end

    it 'defaults to INFO for unknown level' do
      expect(instance.send(:parse_log_level, 'UNKNOWN')).to eq(Logger::INFO)
    end

    it 'handles lowercase' do
      expect(instance.send(:parse_log_level, 'debug')).to eq(Logger::DEBUG)
    end
  end
end
