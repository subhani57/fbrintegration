# frozen_string_literal: true

class AddReceiptDetailsToSubscriptionPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :subscription_payments, :months, :integer
    add_column :subscription_payments, :monthly_fee, :decimal, precision: 10, scale: 2
  end
end
