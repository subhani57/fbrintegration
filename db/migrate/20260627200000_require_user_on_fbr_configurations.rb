class RequireUserOnFbrConfigurations < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      DELETE FROM fbr_configurations WHERE user_id IS NULL
    SQL

    change_column_null :fbr_configurations, :user_id, false
  end

  def down
    change_column_null :fbr_configurations, :user_id, true
  end
end
