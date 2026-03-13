# frozen_string_literal: true

require 'dotenv'
require 'json'
require 'logger'
require 'tzinfo'

module LightspeedSandboxSimulator
  class Configuration
    MERCHANT_KEYS = {
      'LIGHTSPEED_CLIENT_ID' => :client_id,
      'LIGHTSPEED_CLIENT_SECRET' => :client_secret,
      'LIGHTSPEED_ACCESS_TOKEN' => :access_token,
      'LIGHTSPEED_REFRESH_TOKEN' => :refresh_token,
      'LIGHTSPEED_BUSINESS_ID' => :business_id,
      'LIGHTSPEED_DEVICE_NAME' => :device_name
    }.freeze

    DEFAULTS = {
      base_url: 'https://api.lsk.lightspeed.app',
      auth_url: 'https://cloud.lsk.lightspeed.app',
      tax_rate: 20.0,
      merchant_timezone: 'America/New_York'
    }.freeze

    attr_accessor :client_id, :client_secret, :access_token, :refresh_token,
                  :business_id, :base_url, :auth_url, :tax_rate, :log_level,
                  :device_name, :merchant_timezone

    attr_writer :logger

    def initialize
      Dotenv.load if File.exist?('.env')
      @client_id = ENV.fetch('LIGHTSPEED_CLIENT_ID', nil)
      @client_secret = ENV.fetch('LIGHTSPEED_CLIENT_SECRET', nil)
      @access_token = ENV.fetch('LIGHTSPEED_ACCESS_TOKEN', nil)
      @refresh_token = ENV.fetch('LIGHTSPEED_REFRESH_TOKEN', nil)
      @business_id = ENV.fetch('LIGHTSPEED_BUSINESS_ID', nil)
      @base_url = normalize_url(ENV.fetch('LIGHTSPEED_BASE_URL', DEFAULTS[:base_url]))
      @auth_url = normalize_url(ENV.fetch('LIGHTSPEED_AUTH_URL', DEFAULTS[:auth_url]))
      @tax_rate = ENV.fetch('TAX_RATE', DEFAULTS[:tax_rate]).to_f
      @log_level = ENV.fetch('LOG_LEVEL', 'INFO')
      @device_name = ENV.fetch('LIGHTSPEED_DEVICE_NAME', nil)
      @merchant_timezone = ENV.fetch('LIGHTSPEED_TIMEZONE', DEFAULTS[:merchant_timezone])
    end

    def validate!
      raise ConfigurationError, 'LIGHTSPEED_ACCESS_TOKEN is required' if access_token.nil? || access_token.empty?
      raise ConfigurationError, 'LIGHTSPEED_BUSINESS_ID is required' if business_id.nil? || business_id.empty?
    end

    def logger
      @logger ||= build_logger
    end

    def auth_token
      access_token
    end

    def merchant_time_now
      tz = TZInfo::Timezone.get(merchant_timezone)
      tz.now
    rescue TZInfo::InvalidTimezoneIdentifier
      Time.now
    end

    def self.load_from_merchants_file(path = '.env.json')
      return nil unless File.exist?(path)

      data = JSON.parse(File.read(path))
      case data
      when Array
        data
      when Hash
        data['merchants'] || []
      end
    rescue JSON::ParserError
      nil
    end

    def self.load_merchant(index: nil, name: nil, path: '.env.json')
      merchants = load_from_merchants_file(path)
      return nil if merchants.nil? || merchants.empty?

      merchant = find_merchant(merchants, index: index, name: name)
      return nil unless merchant

      build_config_from_merchant(merchant)
    end

    def self.find_merchant(merchants, index: nil, name: nil)
      if name
        merchants.find { |m| m['LIGHTSPEED_DEVICE_NAME']&.downcase == name.downcase }
      elsif index
        merchants[index]
      else
        merchants.first
      end
    end
    private_class_method :find_merchant

    def self.build_config_from_merchant(merchant)
      config = new
      MERCHANT_KEYS.each do |env_key, attr|
        value = merchant[env_key]
        config.public_send(:"#{attr}=", value) unless value.to_s.empty?
      end
      config
    end
    private_class_method :build_config_from_merchant

    def self.available_merchants(path = '.env.json')
      merchants = load_from_merchants_file(path)
      return [] if merchants.nil?

      merchants.map.with_index do |m, i|
        { index: i, name: m['LIGHTSPEED_DEVICE_NAME'], business_id: m['LIGHTSPEED_BUSINESS_ID'] }
      end
    end

    def self.database_url_from_file(path = '.env.json')
      return nil unless File.exist?(path)

      data = JSON.parse(File.read(path))
      data.is_a?(Hash) ? data['DATABASE_URL'] : nil
    rescue JSON::ParserError
      nil
    end

    private

    def normalize_url(url)
      url&.chomp('/')
    end

    def build_logger
      log = Logger.new($stdout)
      log.level = parse_log_level(log_level)
      log.formatter = proc { |severity, _datetime, _progname, msg| "[#{severity}] #{msg}\n" }
      log
    end

    def parse_log_level(level)
      {
        'DEBUG' => Logger::DEBUG, 'INFO' => Logger::INFO,
        'WARN' => Logger::WARN, 'ERROR' => Logger::ERROR,
        'FATAL' => Logger::FATAL
      }.fetch(level.to_s.upcase, Logger::INFO)
    end
  end
end
