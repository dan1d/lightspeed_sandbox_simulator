# frozen_string_literal: true

require 'httparty'
require 'json'
require 'securerandom'

module LightspeedSandboxSimulator
  module Services
    class BaseService
      API_PREFIX = 'api/v2'

      attr_reader :config

      def initialize(config: nil)
        @config = config || LightspeedSandboxSimulator.configuration
        @config.validate!
      end

      private

      def request(method, path, params: nil, payload: nil, resource_type: nil, resource_id: nil)
        url = build_url(path, params)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        response = execute_request(method, url, payload)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        audit_request(method, url, payload, { status: response.code, body: response.body, duration: duration },
                      resource_type: resource_type, resource_id: resource_id)

        handle_error_response(response) unless response.success?

        parse_response(response)
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        audit_request(method, url, payload, { status: 0, body: e.message, duration: duration },
                      resource_type: resource_type, resource_id: resource_id, error: e.message)
        raise ApiError, "HTTP error: #{e.message}"
      end

      def execute_request(method, url, payload)
        options = { headers: build_headers }
        options[:body] = payload.to_json if payload

        case method
        when :get    then HTTParty.get(url, options)
        when :post   then HTTParty.post(url, options)
        when :put    then HTTParty.put(url, options)
        when :delete then HTTParty.delete(url, options)
        else raise ApiError, "Unsupported HTTP method: #{method}"
        end
      end

      def build_headers
        {
          'Authorization' => "Bearer #{config.auth_token}",
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      end

      def build_url(path, params = nil)
        url = if path.start_with?('http')
                path
              else
                "#{config.base_url}/#{path}"
              end

        return url unless params&.any?

        query = params.map { |k, v| "#{k}=#{v}" }.join('&')
        "#{url}?#{query}"
      end

      def endpoint(resource)
        "#{API_PREFIX}/businesses/#{config.business_id}/#{resource}"
      end

      def parse_response(response)
        body = response.body
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        raise ApiError, "Invalid JSON response: #{body[0..200]}"
      end

      def handle_error_response(response)
        body = begin
          JSON.parse(response.body)
        rescue JSON::ParserError, TypeError
          response.body
        end

        raise ApiError, "API error #{response.code}: #{body}"
      end

      def fetch_all_pages(resource, params: {})
        all_items = []
        cursor = nil

        loop do
          request_params = params.merge({})
          request_params[:cursor] = cursor if cursor

          result = request(:get, endpoint(resource), params: request_params)
          return all_items unless result.is_a?(Hash)

          items_key = result.keys.find { |k| result[k].is_a?(Array) }
          items = items_key ? result[items_key] : []
          all_items.concat(items)

          cursor = result['cursor']
          break if cursor.nil? || cursor.empty? || items.empty?
        end

        all_items
      end

      def with_api_fallback(fallback: nil)
        yield
      rescue ApiError, StandardError => e
        LightspeedSandboxSimulator.logger.warn("API fallback: #{e.message}")
        fallback
      end

      def safe_dig(hash, *keys, default: nil)
        return default unless hash.respond_to?(:dig)

        hash.dig(*keys) || default
      rescue StandardError
        default
      end

      def audit_request(method, url, payload, response, resource_type: nil, resource_id: nil, error: nil)
        return unless Database.connected?

        Models::ApiRequest.create!(
          http_method: method.to_s.upcase,
          url: url,
          request_payload: payload&.to_json,
          response_status: response[:status],
          response_payload: truncate_body(response[:body]),
          duration_ms: (response[:duration] * 1000).round,
          resource_type: resource_type,
          resource_id: resource_id,
          error_message: error
        )
      rescue StandardError => e
        LightspeedSandboxSimulator.logger.debug("Audit log failed: #{e.message}")
      end

      def truncate_body(body)
        body.is_a?(String) ? body[0..10_000] : body.to_json[0..10_000]
      end
    end
  end
end
