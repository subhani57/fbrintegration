class AddTimestampsToUsers < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:users)

    add_timestamps :users, null: true unless column_exists?(:users, :created_at)

    return unless column_exists?(:users, :created_at)

    execute <<~SQL.squish
      UPDATE users
      SET created_at = COALESCE(last_sign_in_at, remember_created_at, confirmed_at, NOW()),
          updated_at = COALESCE(last_sign_in_at, remember_created_at, confirmed_at, NOW())
      WHERE created_at IS NULL
    SQL

    change_column_null :users, :created_at, false
    change_column_null :users, :updated_at, false
  end

  def down
    remove_timestamps :users, if_exists: true
  end
end
