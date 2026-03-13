# frozen_string_literal: true

FactoryBot.define do
  factory :category, class: 'LightspeedSandboxSimulator::Models::Category' do
    association :business_type
    name { 'Appetizers' }
    sort_order { 1 }
  end
end
