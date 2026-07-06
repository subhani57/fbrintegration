# frozen_string_literal: true

class AddPoNumberToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :po_number, :string
  end
end
