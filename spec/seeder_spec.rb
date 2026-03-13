# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LightspeedSandboxSimulator::Seeder do
  let(:bt_double) { double('bt', name: 'Test').as_null_object }
  let(:cat_double) { double('cat', name: 'Appetizers', items: double('items_rel').as_null_object).as_null_object }

  before do
    allow(LightspeedSandboxSimulator::Models::BusinessType).to receive(:find_or_create_by!)
      .and_yield(bt_double).and_return(bt_double)
    allow(bt_double).to receive(:categories).and_return(double('cats_rel').as_null_object)
    allow(bt_double.categories).to receive(:find_or_create_by!)
      .and_yield(double('c').as_null_object).and_return(cat_double)
    allow(cat_double.items).to receive(:find_or_create_by!)
      .and_yield(double('i').as_null_object).and_return(double('item'))
  end

  describe '.seed!' do
    it 'raises for unknown business type' do
      expect { described_class.seed!(business_type: :unknown) }
        .to raise_error(LightspeedSandboxSimulator::Error, /Unknown business type/)
    end

    it 'seeds a single business type' do
      result = described_class.seed!(business_type: :restaurant)
      expect(result[:restaurant]).to include(:business_type, :categories, :items)
    end

    it 'accepts :all and seeds all types' do
      result = described_class.seed!(business_type: :all)
      expect(result.keys).to contain_exactly(:restaurant, :cafe_bakery, :bar_nightclub, :retail_general)
    end

    it 'skips items without matching category' do
      # Return a category whose name won't match any item's category field
      non_matching_cat = double('cat', name: 'ZZZ_NO_MATCH', items: double('items_rel').as_null_object)
      allow(bt_double.categories).to receive(:find_or_create_by!)
        .and_yield(double('c').as_null_object).and_return(non_matching_cat)

      result = described_class.seed!(business_type: :restaurant)
      expect(result[:restaurant][:items]).to eq(0)
    end
  end

  describe 'TYPES' do
    it 'includes all four types' do
      expect(described_class::TYPES.keys).to contain_exactly(:restaurant, :cafe_bakery, :bar_nightclub, :retail_general)
    end

    it 'has names and industries' do
      described_class::TYPES.each_value do |config|
        expect(config[:name]).to be_a(String)
        expect(config[:industry]).to be_a(String)
      end
    end
  end

  describe 'private .validate_business_type!' do
    it 'allows :all' do
      expect { described_class.send(:validate_business_type!, :all) }.not_to raise_error
    end

    it 'allows known types' do
      expect { described_class.send(:validate_business_type!, :restaurant) }.not_to raise_error
    end
  end
end
