# frozen_string_literal: true

class CreateSubscriptionPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_payments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 1000
      t.date :active_until, null: false
      t.text :notes

      t.timestamps
    end

    add_index :subscription_payments, [:user_id, :created_at]
  end
end
