# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Generators::OrderGenerator do
  let(:config) do
    c = LightspeedSandboxSimulator::Configuration.new
    c.access_token = 'test-token'
    c.business_id = '12345'
    c
  end
  let(:generator) { described_class.new(config: config, refund_percentage: 0) }
  let(:base_url) { 'https://api.lsk.lightspeed.app/api/v2/businesses/12345' }

  let(:sample_items) do
    [
      { 'id' => 1, 'name' => 'Coffee', 'price' => 4.50 },
      { 'id' => 2, 'name' => 'Muffin', 'price' => 3.99 },
      { 'id' => 3, 'name' => 'Sandwich', 'price' => 8.99 }
    ]
  end

  let(:sample_payment_methods) do
    [
      { 'id' => 1, 'name' => 'Cash', 'type' => 'CASH' },
      { 'id' => 2, 'name' => 'Credit Card', 'type' => 'CARD' }
    ]
  end

  before do
    stub_request(:get, "#{base_url}/menu/items")
      .to_return(status: 200, body: { 'items' => sample_items }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/payment-methods")
      .to_return(status: 200, body: { 'paymentMethods' => sample_payment_methods }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, "#{base_url}/orders/local")
      .to_return do
      { status: 201, body: { 'id' => rand(1000..9999), 'orderType' => 'local', 'items' => [] }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end

    stub_request(:post, "#{base_url}/orders/toGo")
      .to_return do
      { status: 201, body: { 'id' => rand(1000..9999), 'orderType' => 'toGo', 'items' => [] }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end

    stub_request(:post, "#{base_url}/payments")
      .to_return do
      { status: 201, body: { 'id' => rand(1000..9999) }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end
  end

  describe '#generate_today' do
    it 'generates the specified number of orders' do
      orders = generator.generate_today(count: 3)
      expect(orders.size).to eq(3)
    end

    it 'filters out nil orders' do
      stub_request(:post, "#{base_url}/orders/local")
        .to_return(status: 204, body: '', headers: {})
      stub_request(:post, "#{base_url}/orders/toGo")
        .to_return(status: 204, body: '', headers: {})

      orders = generator.generate_today(count: 2)
      expect(orders).to be_empty
    end

    it 'generates without count using day-of-week pattern' do
      orders = generator.generate_today
      expect(orders.size).to be_between(40, 120)
    end

    it 'processes refunds when refund_percentage is positive' do
      gen = described_class.new(config: config, refund_percentage: 100)
      orders = gen.generate_today(count: 3)
      expect(orders).not_to be_empty
    end

    it 'generates summary when DB connected' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::DailySummary).to receive(:generate_for!).and_return(true)
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(
        double('order', id: 'abc')
      )
      allow(LightspeedSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      orders = generator.generate_today(count: 1)
      expect(orders).not_to be_empty
    end

    it 'handles summary generation failure gracefully' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::DailySummary).to receive(:generate_for!)
        .and_raise(StandardError, 'summary error')
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(
        double('order', id: 'abc')
      )
      allow(LightspeedSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      expect { generator.generate_today(count: 1) }.not_to raise_error
    end
  end

  describe '#generate_realistic_day' do
    it 'uses multiplier for volume' do
      orders = generator.generate_realistic_day(multiplier: 0.1)
      expect(orders.size).to be_between(1, 20)
    end
  end

  describe '#generate_rush' do
    it 'generates orders for a specific period' do
      orders = generator.generate_rush(period: :lunch, count: 5)
      expect(orders.size).to eq(5)
    end

    it 'filters out nil orders from rush' do
      stub_request(:post, "#{base_url}/orders/local")
        .to_return(status: 204, body: '', headers: {})
      stub_request(:post, "#{base_url}/orders/toGo")
        .to_return(status: 204, body: '', headers: {})

      orders = generator.generate_rush(period: :dinner, count: 2)
      expect(orders).to be_empty
    end

    it 'generates dinner rush' do
      orders = generator.generate_rush(period: :dinner, count: 3)
      expect(orders.size).to eq(3)
    end

    it 'generates breakfast rush' do
      orders = generator.generate_rush(period: :breakfast, count: 2)
      expect(orders.size).to eq(2)
    end

    it 'generates happy_hour rush' do
      orders = generator.generate_rush(period: :happy_hour, count: 2)
      expect(orders.size).to eq(2)
    end

    it 'generates late_night rush' do
      orders = generator.generate_rush(period: :late_night, count: 2)
      expect(orders.size).to eq(2)
    end
  end

  describe 'meal period distribution' do
    it 'distributes orders across periods' do
      distribution = generator.send(:distribute_across_periods, 100)
      expect(distribution.values.sum).to eq(100)
      expect(distribution[:dinner]).to be > distribution[:late_night]
    end

    it 'handles small counts' do
      distribution = generator.send(:distribute_across_periods, 5)
      expect(distribution.values.sum).to eq(5)
    end
  end

  describe 'weighted selection' do
    it 'selects from weighted options' do
      weights = { a: 90, b: 10 }
      results = 100.times.map { generator.send(:weighted_select, weights) }
      expect(results.count(:a)).to be > 50
    end

    it 'returns last key as fallback for zero weights' do
      weights = { only: 0 }
      result = generator.send(:weighted_select, weights)
      expect(result).to eq(:only)
    end
  end

  describe 'discount calculation' do
    it 'returns 0 most of the time' do
      results = 1000.times.map { generator.send(:calculate_discount, 100.0) }
      zero_count = results.count(0.0)
      expect(zero_count).to be_between(850, 1000)
    end
  end

  describe 'tip calculation' do
    it 'calculates tips for eat_in' do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :eat_in) }
      expect(tips.any? { |t| t > 0 }).to be true
    end

    it 'calculates tips for takeaway' do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :takeaway) }
      zero_count = tips.count(0.0)
      expect(zero_count).to be > 30
    end

    it 'calculates tips for delivery' do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :delivery) }
      expect(tips.any? { |t| t > 0 }).to be true
    end

    it 'uses default for unknown dining option' do
      tips = 100.times.map { generator.send(:calculate_tip, 50.0, :unknown) }
      expect(tips).to all(be >= 0)
    end
  end

  describe 'payment method selection' do
    it 'selects based on weighted config' do
      tenders_config = [{ 'name' => 'cash', 'weight' => 50 }, { 'name' => 'credit card', 'weight' => 50 }]
      result = generator.send(:select_payment_method, sample_payment_methods, tenders_config)
      expect(result).to be_in(sample_payment_methods)
    end

    it 'returns first method when config empty' do
      result = generator.send(:select_payment_method, sample_payment_methods, [])
      expect(result).to eq(sample_payment_methods.first)
    end

    it 'handles nil payment method names' do
      methods_with_nil = [{ 'id' => 1, 'name' => nil }, { 'id' => 2, 'name' => 'Cash' }]
      tenders = [{ 'name' => 'Cash', 'weight' => 100 }]
      result = generator.send(:select_payment_method, methods_with_nil, tenders)
      expect(result['name']).to eq('Cash')
    end

    it 'returns first method when no matches' do
      result = generator.send(:select_payment_method, sample_payment_methods,
                              [{ 'name' => 'bitcoin', 'weight' => 100 }])
      expect(result).to eq(sample_payment_methods.first)
    end
  end

  describe 'daily order count' do
    it 'returns count within range' do
      count = generator.send(:daily_order_count)
      expect(count).to be_between(40, 120)
    end
  end

  describe 'create_order paths' do
    it 'creates to_go order for takeaway' do
      result = generator.send(:create_order, :to_go, [{ item_id: 1, quantity: 1 }])
      expect(result).not_to be_nil
    end

    it 'creates local order for eat_in' do
      result = generator.send(:create_order, :local, [{ item_id: 1, quantity: 1 }])
      expect(result).not_to be_nil
    end
  end

  describe 'fetch_required_data with raw array responses' do
    it 'handles items as raw array' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: sample_items.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      data = generator.send(:fetch_required_data)
      expect(data[:items].size).to eq(3)
    end

    it 'handles payment methods as raw array' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: sample_payment_methods.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      data = generator.send(:fetch_required_data)
      expect(data[:payment_methods].size).to eq(2)
    end
  end

  describe 'fetch_required_data' do
    it 'raises when no items found' do
      stub_request(:get, "#{base_url}/menu/items")
        .to_return(status: 200, body: { 'items' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { generator.send(:fetch_required_data) }.to raise_error(LightspeedSandboxSimulator::Error, /No items/)
    end

    it 'raises when no payment methods found' do
      stub_request(:get, "#{base_url}/payment-methods")
        .to_return(status: 200, body: { 'paymentMethods' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { generator.send(:fetch_required_data) }.to raise_error(LightspeedSandboxSimulator::Error, /No payment/)
    end
  end

  describe 'generate_single_order error handling' do
    it 'returns nil when items list is empty' do
      data = { items: [], payment_methods: sample_payment_methods, tenders_config: [] }
      result = generator.send(:generate_single_order, data, period: :lunch)
      expect(result).to be_nil
    end

    it 'returns nil when create_order returns nil' do
      stub_request(:post, "#{base_url}/orders/local")
        .to_return(status: 204, body: '', headers: {})
      stub_request(:post, "#{base_url}/orders/toGo")
        .to_return(status: 204, body: '', headers: {})

      data = { items: sample_items, payment_methods: sample_payment_methods, tenders_config: [] }
      result = generator.send(:generate_single_order, data, period: :lunch)
      expect(result).to be_nil
    end

    it 'returns nil on API failure' do
      stub_request(:post, "#{base_url}/orders/local")
        .to_return(status: 500, body: { 'error' => 'fail' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, "#{base_url}/orders/toGo")
        .to_return(status: 500, body: { 'error' => 'fail' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      data = { items: sample_items, payment_methods: sample_payment_methods, tenders_config: [] }
      result = generator.send(:generate_single_order, data, period: :lunch)
      expect(result).to be_nil
    end
  end

  describe 'persist_order' do
    it 'creates SimulatedOrder and SimulatedPayment' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      order_double = double('order', id: 'uuid-1')
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(order_double)
      allow(LightspeedSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      result = { 'id' => 42, 'orderType' => 'local', 'items' => [{ 'id' => 1 }] }
      pm = { 'name' => 'Cash', 'type' => 'CASH' }
      generator.send(:persist_order, result, :lunch, :eat_in, 1.65, 3.0, 0.0, 24.65, pm)

      expect(LightspeedSandboxSimulator::Models::SimulatedOrder).to have_received(:create!)
      expect(LightspeedSandboxSimulator::Models::SimulatedPayment).to have_received(:create!)
    end

    it 'handles persistence errors gracefully' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:create!)
        .and_raise(StandardError, 'db error')

      result = { 'id' => 42, 'items' => [] }
      pm = { 'name' => 'Cash', 'type' => 'CASH' }
      expect do
        generator.send(:persist_order, result, :lunch, :eat_in, 1.65, 0.0, 0.0, 21.65, pm)
      end.not_to raise_error
    end

    it 'uses orderId when id is missing' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      order_double = double('order', id: 'uuid-1')
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(order_double)
      allow(LightspeedSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      result = { 'orderId' => 99, 'orderType' => 'toGo', 'items' => [] }
      pm = { 'name' => 'Cash', 'type' => 'CASH' }
      generator.send(:persist_order, result, :lunch, :takeaway, 1.65, 0.0, 0.0, 21.65, pm)

      expect(LightspeedSandboxSimulator::Models::SimulatedOrder).to have_received(:create!)
        .with(hash_including(order_id: '99'))
    end

    it 'handles nil payment method name' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      order_double = double('order', id: 'uuid-1')
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:create!).and_return(order_double)
      allow(LightspeedSandboxSimulator::Models::SimulatedPayment).to receive(:create!)

      result = { 'id' => 42, 'items' => nil }
      pm = { 'name' => nil, 'type' => nil }
      generator.send(:persist_order, result, :lunch, :eat_in, 1.65, 0.0, 0.0, 21.65, pm)

      expect(LightspeedSandboxSimulator::Models::SimulatedPayment).to have_received(:create!)
    end
  end

  describe 'refund processing' do
    it 'processes refunds on orders' do
      gen = described_class.new(config: config, refund_percentage: 50)
      expect { gen.generate_today(count: 4) }.not_to raise_error
    end

    it 'updates DB records when connected' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      sim_double = double('SimulatedOrder')
      allow(sim_double).to receive(:update!)
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive_messages(
        find_by: sim_double, create!: double('order', id: 'x')
      )
      allow(LightspeedSandboxSimulator::Models::SimulatedPayment).to receive(:create!)
      allow(LightspeedSandboxSimulator::Models::DailySummary).to receive(:generate_for!)

      gen = described_class.new(config: config, refund_percentage: 50)
      gen.generate_today(count: 2)
      expect(LightspeedSandboxSimulator::Models::SimulatedOrder).to have_received(:find_by).at_least(:once)
    end

    it 'skips orders without id' do
      gen = described_class.new(config: config, refund_percentage: 100)
      orders = [{ 'id' => nil }]
      gen.send(:process_refunds, orders)
    end

    it 'handles mark_order_refunded errors gracefully' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:find_by)
        .and_raise(StandardError, 'db down')

      gen = described_class.new(config: config, refund_percentage: 100)
      orders = [{ 'id' => 123 }]
      expect { gen.send(:process_refunds, orders) }.not_to raise_error
    end

    it 'handles SimulatedOrder not found' do
      allow(LightspeedSandboxSimulator::Database).to receive(:connected?).and_return(true)
      allow(LightspeedSandboxSimulator::Models::SimulatedOrder).to receive(:find_by).and_return(nil)

      gen = described_class.new(config: config, refund_percentage: 100)
      orders = [{ 'id' => 123 }]
      expect { gen.send(:process_refunds, orders) }.not_to raise_error
    end

    it 'handles empty orders array' do
      expect { generator.send(:process_refunds, []) }.not_to raise_error
    end

    it 'skips when refund_count is zero' do
      zero_gen = described_class.new(config: config, refund_percentage: 0)
      orders = [{ 'id' => 1 }, { 'id' => 2 }]
      zero_gen.send(:process_refunds, orders)
    end
  end

  describe 'create_payment' do
    it 'skips when order has no id' do
      result = generator.send(:create_payment, {}, 25.0, 3.0, { 'id' => 1 })
      expect(result).to be_nil
    end

    it 'skips when payment method has no id' do
      result = generator.send(:create_payment, { 'id' => 100 }, 25.0, 3.0, {})
      expect(result).to be_nil
    end
  end

  describe 'weighted_select_tender' do
    it 'returns name from tenders config' do
      config_data = [{ 'name' => 'Cash', 'weight' => 100 }]
      result = generator.send(:weighted_select_tender, config_data)
      expect(result).to eq('Cash')
    end

    it 'handles zero total weight' do
      config_data = [{ 'name' => 'Cash', 'weight' => 0 }]
      result = generator.send(:weighted_select_tender, config_data)
      expect(result).to eq('Cash')
    end
  end
end
