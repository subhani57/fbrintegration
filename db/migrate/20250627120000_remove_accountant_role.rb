class RemoveAccountantRole < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:users) && column_exists?(:users, :role)

    execute <<~SQL.squish
      UPDATE users SET role = 'taxpayer' WHERE role = 'accountant'
    SQL
  end

  def down
    # accountant role is no longer supported
  end
end
