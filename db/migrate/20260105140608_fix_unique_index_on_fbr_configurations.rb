class FixUniqueIndexOnFbrConfigurations < ActiveRecord::Migration[7.1]
  def change
    # Remove old global unique index
    remove_index :fbr_configurations, :environment if index_exists?(:fbr_configurations, :environment)

    # Add unique index scoped to user_id
    add_index :fbr_configurations, [:environment, :user_id], unique: true
  end
end
