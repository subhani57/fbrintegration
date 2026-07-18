class IncreaseInvoiceItemUnitPricePrecision < ActiveRecord::Migration[8.0]
  def up
    change_column :invoice_items, :unit_price, :decimal, precision: 20, scale: 8
  end

  def down
    change_column :invoice_items, :unit_price, :decimal, precision: 15, scale: 2
  end
end
