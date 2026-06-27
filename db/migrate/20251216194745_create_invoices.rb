class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    # 1. FBR Scenarios
    create_table :fbr_scenarios do |t|
      t.string :scenario_id, null: false
      t.string :name, null: false
      t.string :description
      t.string :sale_type
      t.boolean :active, default: true
      t.timestamps
      t.index :scenario_id, unique: true
    end

    # 2. Invoices
    create_table :invoices do |t|
      t.string :invoice_number
      t.string :sro_schedule_no
      t.string :fbr_invoice_id
      t.date :invoice_date
      t.string :invoice_type
      t.string :seller_ntn
       t.string :seller_name
      t.string :seller_province
      t.text :seller_address
      t.string :buyer_ntn
      t.string :buyer_name
      t.string :buyer_province
      t.text :buyer_address
      t.string :buyer_registration_type
      t.decimal :total_amount, precision: 15, scale: 2
      t.decimal :tax_amount, precision: 15, scale: 2
      t.string :scenario_id
      t.string :status
      t.string :fbr_status
      t.text :error_message
      t.integer :retry_count, default: 0
      t.datetime :submitted_at
      t.json :test_data
      t.json :response_data
      t.timestamps
      t.index :invoice_number, unique: true
      t.index :fbr_invoice_id
      t.index :scenario_id
    end

    # 3. Invoice Items
    create_table :invoice_items do |t|
      t.references :invoice, foreign_key: true
      t.string :hs_code
      t.text :description
      t.decimal :quantity, precision: 15, scale: 4
      t.string :uom
      t.decimal :unit_price, precision: 15, scale: 2
      t.decimal :tax_rate, precision: 5, scale: 2
      t.decimal :sales_tax, precision: 15, scale: 2
      t.decimal :total_value, precision: 15, scale: 2
      t.string :sale_type
      t.timestamps
    end

    # 4. FBR Configurations
    create_table :fbr_configurations do |t|
      t.string :environment, null: false
      t.string :token
      t.string :api_key
      t.datetime :token_expires_at
      t.boolean :active, default: false
      t.timestamps
      t.index :environment, unique: true
    end

    # 5. Business Mappings
    create_table :business_scenario_mappings do |t|
      t.string :business_nature, null: false
      t.string :sector, null: false
      t.string :scenario_ids, array: true, default: []
      t.boolean :active, default: true
      t.timestamps
      t.index [:business_nature, :sector], unique: true
    end
  end
end