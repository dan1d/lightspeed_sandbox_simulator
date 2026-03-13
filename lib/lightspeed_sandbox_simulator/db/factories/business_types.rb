# frozen_string_literal: true

FactoryBot.define do
  factory :business_type, class: 'LightspeedSandboxSimulator::Models::BusinessType' do
    key { 'restaurant' }
    name { 'Restaurant' }
    industry { 'food' }
  end
end
