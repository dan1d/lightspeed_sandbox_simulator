# frozen_string_literal: true

class CreateSimulatedPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :simulated_payments, id: :uuid do |t|
      t.references :simulated_order, type: :uuid, null: false, foreign_key: true
      t.string :payment_id
      t.string :tender_name
      t.string :tender_type
      t.string :status, default: 'successful'
      t.integer :amount, default: 0
      t.integer :tip_amount, default: 0
      t.timestamps
    end
  end
end
