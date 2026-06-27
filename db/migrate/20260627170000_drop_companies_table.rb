class DropCompaniesTable < ActiveRecord::Migration[8.1]
  def up
    drop_table :companies, if_exists: true
  end

  def down
    return if table_exists?(:companies)

    create_table :companies do |t|
      t.string :name, null: false
      t.string :ntn
      t.string :province
      t.text :address
      t.string :phone
      t.string :email
      t.string :company_type
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :companies, :ntn, unique: true
  end
end
