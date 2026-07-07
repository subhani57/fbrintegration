class AddSubscriptionFreeForeverToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :subscription_free_forever, :boolean, default: false, null: false
  end
end
