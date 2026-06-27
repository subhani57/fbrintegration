class AddUserIdToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_reference :invoices, :user, null: false, foreign_key: true
  end
end
