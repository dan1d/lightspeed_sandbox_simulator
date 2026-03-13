# frozen_string_literal: true

FactoryBot.define do
  factory :item, class: 'LightspeedSandboxSimulator::Models::Item' do
    association :category
    name { 'Buffalo Wings' }
    price { 1299 }
    sku { 'WING-001' }
    taxable { true }
  end
end
