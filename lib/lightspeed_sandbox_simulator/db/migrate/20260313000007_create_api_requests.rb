# frozen_string_literal: true

class CreateApiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :api_requests, id: :uuid do |t|
      t.string :http_method
      t.text :url
      t.text :request_payload
      t.integer :response_status
      t.text :response_payload
      t.integer :duration_ms
      t.string :resource_type
      t.string :resource_id
      t.text :error_message
      t.timestamps
    end
  end
end
