class AddBusinessDetailsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :ntn_cnic, :string
    add_column :users, :business_name, :string
    add_column :users, :address, :text
  end
end
