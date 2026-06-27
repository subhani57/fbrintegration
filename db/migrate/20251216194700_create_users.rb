class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:users)

    create_table :users do |t|
      t.timestamps
    end
  end
end
