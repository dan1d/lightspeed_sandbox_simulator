# frozen_string_literal: true

class CreateDailySummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_summaries, id: :uuid do |t|
      t.date :summary_date, null: false
      t.integer :order_count, default: 0
      t.integer :payment_count, default: 0
      t.integer :refund_count, default: 0
      t.integer :total_revenue, default: 0
      t.integer :total_tax, default: 0
      t.integer :total_tips, default: 0
      t.integer :total_discounts, default: 0
      t.jsonb :breakdown, default: {}
      t.timestamps
    end

    add_index :daily_summaries, :summary_date, unique: true
  end
end
