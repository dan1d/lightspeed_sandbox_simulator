# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: :uuid do |t|
      t.references :business_type, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description
      t.integer :sort_order, default: 0
      t.timestamps
    end
  end
end
