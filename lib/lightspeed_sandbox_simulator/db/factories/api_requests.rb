# frozen_string_literal: true

FactoryBot.define do
  factory :api_request, class: 'LightspeedSandboxSimulator::Models::ApiRequest' do
    http_method { 'GET' }
    url { 'https://api.lsk.lightspeed.app/api/v2/businesses/123/menu/categories' }
    response_status { 200 }
    duration_ms { 150 }
  end
end
