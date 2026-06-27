
class CreateCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :companies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :ntn
      t.string :province
      t.text :address
      t.string :phone
      t.string :email
      t.string :company_type

      t.timestamps
    end
    add_index :companies, :ntn, unique: true
  end
end
