class AddPreferredFbrEnvironmentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_fbr_environment, :string, default: 'sandbox', null: false
    add_index :users, :preferred_fbr_environment
  end
end
