# frozen_string_literal: true

class CreateSubscriptionPaymentLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_payment_line_items do |t|
      t.references :subscription_payment, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, default: 1, null: false
      t.decimal :unit_amount, precision: 10, scale: 2, default: 0, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
