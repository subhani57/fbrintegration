class AddSroScheduleNoToInvoiceItems < ActiveRecord::Migration[7.1]
  def change
    add_column :invoice_items, :sro_schedule_no, :string
  end
end
