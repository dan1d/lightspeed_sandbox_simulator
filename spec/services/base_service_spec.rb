# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Services::BaseService do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:service) { described_class.new(config: config) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  describe '#initialize' do
    it 'uses default configuration' do
      allow(LightspeedSandboxSimulator).to receive(:configuration).and_return(config)
      svc = described_class.new
      expect(svc.config).to eq(config)
    end

    it 'validates configuration' do
      config.access_token = nil
      expect { described_class.new(config: config) }.to raise_error(LightspeedSandboxSimulator::ConfigurationError)
    end
  end

  describe 'API_PREFIX' do
    it 'uses V2 prefix' do
      expect(described_class::API_PREFIX).to eq('api/v2')
    end
  end

  describe '#request' do
    it 'makes GET requests with Bearer auth' do
      stub_request(:get, "#{base_url}/menu/categories")
        .with(headers: { 'Authorization' => 'Bearer test-token' })
        .to_return(status: 200, body: { 'categories' => [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.send(:request, :get, 'api/v2/businesses/12345/menu/categories')
      expect(result['categories']).to eq([])
    end

    it 'makes POST requests with JSON body' do
      stub_request(:post, "#{base_url}/menu/categories")
        .to_return(status: 201, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.send(:request, :post, 'api/v2/businesses/12345/menu/categories',
                            payload: { name: 'Test' })
      expect(result['id']).to eq(1)
    end

    it 'makes PUT requests' do
      stub_request(:put, "#{base_url}/menu/categories/1")
        .to_return(status: 200, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.send(:request, :put, 'api/v2/businesses/12345/menu/categories/1',
                            payload: { name: 'Updated' })
      expect(result['id']).to eq(1)
    end

    it 'makes DELETE requests' do
      stub_request(:delete, "#{base_url}/menu/categories/1")
        .to_return(status: 204, body: '', headers: {})

      expect { service.send(:request, :delete, 'api/v2/businesses/12345/menu/categories/1') }.not_to raise_error
    end

    it 'raises on unsupported HTTP method' do
      expect do
        service.send(:request, :patch, 'api/v2/businesses/12345/menu/categories')
      end.to raise_error(LightspeedSandboxSimulator::ApiError, /Unsupported HTTP method/)
    end

    it 'raises ApiError on HTTP error' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 401, body: { 'message' => 'Unauthorized' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect do
        service.send(:request, :get, 'api/v2/businesses/12345/menu/categories')
      end.to raise_error(LightspeedSandboxSimulator::ApiError, /401/)
    end

    it 'handles non-JSON error response body' do
      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 500, body: 'plain text error', headers: { 'Content-Type' => 'text/plain' })

      expect do
        service.send(:request, :get, 'api/v2/businesses/12345/menu/categories')
      end.to raise_error(LightspeedSandboxSimulator::ApiError)
    end

    it 'makes POST request without payload' do
      stub_request(:post, "#{base_url}/menu/categories")
        .to_return(status: 201, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.send(:request, :post, 'api/v2/businesses/12345/menu/categories')
      expect(result['id']).to eq(1)
    end

    it 'audits API requests when DB connected' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::ApiRequest).to receive(:create!)

      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

      service.send(:request, :get, 'api/v2/businesses/12345/menu/categories')
      expect(LightspeedSandboxSimulator::Models::ApiRequest).to have_received(:create!)
    end

    it 'handles audit logging failure gracefully' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::ApiRequest).to receive(:create!).and_raise(StandardError, 'db error')

      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

      expect { service.send(:request, :get, 'api/v2/businesses/12345/menu/categories') }.not_to raise_error
    end

    it 'audits failed API requests' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::ApiRequest).to receive(:create!)

      stub_request(:get, "#{base_url}/menu/categories")
        .to_return(status: 500, body: { 'error' => 'fail' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect do
        service.send(:request, :get, 'api/v2/businesses/12345/menu/categories')
      end.to raise_error(LightspeedSandboxSimulator::ApiError)
      expect(LightspeedSandboxSimulator::Models::ApiRequest).to have_received(:create!)
    end

    it 'audits with non-string body' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::ApiRequest).to receive(:create!)

      service.send(:audit_request, :get, 'http://test', nil,
                   { status: 200, body: { 'key' => 'val' }, duration: 0.1 })
      expect(LightspeedSandboxSimulator::Models::ApiRequest).to have_received(:create!)
        .with(hash_including(response_payload: '{"key":"val"}'))
    end

    it 'audits with error parameter' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::ApiRequest).to receive(:create!)

      service.send(:audit_request, :get, 'http://test', nil,
                   { status: 0, body: 'connection refused', duration: 0.1 },
                   error: 'connection refused')
      expect(LightspeedSandboxSimulator::Models::ApiRequest).to have_received(:create!)
        .with(hash_including(error_message: 'connection refused'))
    end

    it 'raises ApiError on network errors' do
      stub_request(:get, "#{base_url}/menu/categories").to_raise(SocketError.new('connection refused'))

      expect do
        service.send(:request, :get, 'api/v2/businesses/12345/menu/categories')
      end.to raise_error(LightspeedSandboxSimulator::ApiError, /HTTP error/)
    end

    it 'passes resource_type and resource_id for audit' do
      stub_request(:get, "#{base_url}/menu/categories/1")
        .to_return(status: 200, body: { 'id' => 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.send(:request, :get, 'api/v2/businesses/12345/menu/categories/1',
                            resource_type: 'Category', resource_id: '1')
      expect(result['id']).to eq(1)
    end
  end

  describe '#endpoint' do
    it 'builds API endpoint path' do
      expect(service.send(:endpoint, 'menu/categories')).to eq('api/v2/businesses/12345/menu/categories')
    end
  end

  describe '#build_url' do
    it 'builds URL from relative path' do
      url = service.send(:build_url, 'api/v2/businesses/12345/menu/categories')
      expect(url).to include('api.lsk.lightspeed.app')
    end

    it 'uses absolute URL' do
      url = service.send(:build_url, 'https://custom.api.com/v2/test')
      expect(url).to eq('https://custom.api.com/v2/test')
    end

    it 'appends query params' do
      url = service.send(:build_url, 'api/v2/test', { cursor: 'abc', limit: 100 })
      expect(url).to include('cursor=abc')
      expect(url).to include('limit=100')
    end

    it 'returns URL without params when nil' do
      url = service.send(:build_url, 'api/v2/test', nil)
      expect(url).not_to include('?')
    end
  end

  describe '#parse_response' do
    it 'returns nil for nil body' do
      response = double('response', body: nil)
      expect(service.send(:parse_response, response)).to be_nil
    end

    it 'returns nil for empty body' do
      response = double('response', body: '')
      expect(service.send(:parse_response, response)).to be_nil
    end

    it 'parses valid JSON' do
      response = double('response', body: '{"id":1}')
      expect(service.send(:parse_response, response)).to eq({ 'id' => 1 })
    end

    it 'raises ApiError on invalid JSON' do
      response = double('response', body: 'not json')
      expect do
        service.send(:parse_response, response)
      end.to raise_error(LightspeedSandboxSimulator::ApiError, /Invalid JSON/)
    end
  end

  describe '#fetch_all_pages' do
    it 'fetches pages using cursor' do
      stub_request(:get, "#{base_url}/payments")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 1 }], 'cursor' => 'abc' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{base_url}/payments?cursor=abc")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 2 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.send(:fetch_all_pages, 'payments')
      expect(result.size).to eq(2)
    end

    it 'stops at empty cursor' do
      stub_request(:get, "#{base_url}/payments")
        .to_return(status: 200, body: { 'payments' => [{ 'id' => 1 }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.send(:fetch_all_pages, 'payments')
      expect(result.size).to eq(1)
    end

    it 'returns empty for non-hash response' do
      stub_request(:get, "#{base_url}/payments")
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.send(:fetch_all_pages, 'payments')
      expect(result).to eq([])
    end

    it 'handles response without array key' do
      stub_request(:get, "#{base_url}/payments")
        .to_return(status: 200, body: { 'error' => 'bad' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = service.send(:fetch_all_pages, 'payments')
      expect(result).to eq([])
    end
  end

  describe '#with_api_fallback' do
    it 'returns block result on success' do
      result = service.send(:with_api_fallback, fallback: 'default') { 'success' }
      expect(result).to eq('success')
    end

    it 'returns fallback on ApiError' do
      result = service.send(:with_api_fallback, fallback: 'default') do
        raise LightspeedSandboxSimulator::ApiError, 'failed'
      end
      expect(result).to eq('default')
    end

    it 'returns fallback on StandardError' do
      result = service.send(:with_api_fallback, fallback: 'default') do
        raise StandardError, 'oops'
      end
      expect(result).to eq('default')
    end
  end

  describe '#safe_dig' do
    it 'digs into nested hashes' do
      expect(service.send(:safe_dig, { 'a' => { 'b' => 'v' } }, 'a', 'b')).to eq('v')
    end

    it 'returns default for missing keys' do
      expect(service.send(:safe_dig, {}, 'a', 'b', default: 'fb')).to eq('fb')
    end

    it 'returns default for nil hash' do
      expect(service.send(:safe_dig, nil, 'a', default: 'fb')).to eq('fb')
    end

    it 'returns default when dig raises error' do
      bad_hash = {}
      allow(bad_hash).to receive(:respond_to?).and_call_original
      allow(bad_hash).to receive(:dig).and_raise(TypeError, 'bad')
      expect(service.send(:safe_dig, bad_hash, 'a', default: 'fb')).to eq('fb')
    end
  end
end
