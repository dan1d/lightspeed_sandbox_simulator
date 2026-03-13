# frozen_string_literal: true

require 'zeitwerk'
require 'logger'

module LightspeedSandboxSimulator
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      configuration.logger
    end
  end
end

loader = Zeitwerk::Loader.for_gem
loader.setup
# :nocov:
loader.eager_load if ENV['RACK_ENV'] == 'production'
# :nocov:
