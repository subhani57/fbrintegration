# frozen_string_literal: true

class AddStatusToSubscriptionPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :subscription_payments, :status, :string, default: 'paid', null: false
    add_column :subscription_payments, :paid_at, :datetime
    add_index :subscription_payments, :status

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE subscription_payments
          SET paid_at = created_at
          WHERE status = 'paid' AND paid_at IS NULL
        SQL
      end
    end
  end
end
