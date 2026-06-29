class AddSubscriptionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :subscription_active_until, :date
    add_index :users, :subscription_active_until
  end
end
