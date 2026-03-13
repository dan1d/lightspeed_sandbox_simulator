# frozen_string_literal: true

class CreateSimulatedOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_orders, id: :uuid do |t|
      t.string :order_id
      t.string :order_type
      t.string :status, default: 'paid'
      t.string :meal_period
      t.string :dining_option
      t.date :order_date
      t.integer :total, default: 0
      t.integer :tax_amount, default: 0
      t.integer :tip_amount, default: 0
      t.integer :discount_amount, default: 0
      t.integer :item_count, default: 0
      t.timestamps
    end

    add_index :simulated_orders, :order_date
    add_index :simulated_orders, :status
  end
end
