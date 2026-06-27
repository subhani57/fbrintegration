class AddPdfInvoiceNumberToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :pdf_invoice_number, :string
  end
end
