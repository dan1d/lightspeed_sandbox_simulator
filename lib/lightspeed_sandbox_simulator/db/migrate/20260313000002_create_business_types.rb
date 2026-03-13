# frozen_string_literal: true

class CreateBusinessTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :business_types, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :industry, default: 'food'
      t.timestamps
    end

    add_index :business_types, :key, unique: true
  end
end
