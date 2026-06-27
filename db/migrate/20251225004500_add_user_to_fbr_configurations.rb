class AddUserToFbrConfigurations < ActiveRecord::Migration[7.1]
  def change
    add_reference :fbr_configurations, :user, foreign_key: true, null: true
    add_index :fbr_configurations, [:user_id, :environment], unique: true
  end
end
