class AddBuyerCompanyToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_reference :invoices, :buyer_company, foreign_key: { to_table: :companies }, null: true
  end
end
