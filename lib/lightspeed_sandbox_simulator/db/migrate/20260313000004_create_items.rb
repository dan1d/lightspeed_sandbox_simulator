# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items, id: :uuid do |t|
      t.references :category, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price, null: false
      t.string :sku
      t.boolean :taxable, default: true
      t.timestamps
    end
  end
end
