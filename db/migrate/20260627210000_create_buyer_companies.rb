class CreateBuyerCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :ntn, null: false
      t.string :province, null: false, default: 'Punjab'
      t.string :registration_type, null: false, default: 'Registered'
      t.text :address
      t.string :phone
      t.string :email

      t.timestamps
    end

    add_index :companies, [:user_id, :ntn], unique: true
    add_index :companies, [:user_id, :name]
  end
end
