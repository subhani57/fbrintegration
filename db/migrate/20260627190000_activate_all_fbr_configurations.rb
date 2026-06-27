class ActivateAllFbrConfigurations < ActiveRecord::Migration[8.1]
  def up
    FbrConfiguration.update_all(active: true)
  end

  def down
    # active flag is no longer user-controlled
  end
end
