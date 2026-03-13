# frozen_string_literal: true

FactoryBot.define do
  factory :simulated_order, class: 'LightspeedSandboxSimulator::Models::SimulatedOrder' do
    order_id { rand(1000..9999).to_s }
    order_type { 'local' }
    status { 'paid' }
    meal_period { 'lunch' }
    dining_option { 'eat_in' }
    order_date { Date.today }
    total { 2500 }
    tax_amount { 500 }
    tip_amount { 375 }
    discount_amount { 0 }
    item_count { 3 }
  end
end
