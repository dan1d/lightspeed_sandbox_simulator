# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/db/migrate/'
    add_filter '/db/factories/'
    enable_coverage :branch
    minimum_coverage line: 100, branch: 100
  end
end

require 'lightspeed_sandbox_simulator'
require 'webmock/rspec'
require 'factory_bot'

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed

  config.before do
    allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(false)
  end
end
