class ScopeInvoiceNumberUniquenessToUser < ActiveRecord::Migration[8.1]
  def change
    remove_index :invoices, :invoice_number
    add_index :invoices, [:user_id, :invoice_number], unique: true
  end
end
