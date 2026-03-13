# frozen_string_literal: true

FactoryBot.define do
  factory :simulated_payment, class: 'LightspeedSandboxSimulator::Models::SimulatedPayment' do
    association :simulated_order
    payment_id { rand(1000..9999).to_s }
    tender_name { 'Cash' }
    tender_type { 'CASH' }
    status { 'successful' }
    amount { 2500 }
    tip_amount { 375 }
  end
end
