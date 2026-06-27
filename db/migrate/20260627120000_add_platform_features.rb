# frozen_string_literal: true

class AddPlatformFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :fbr_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.string :log_type, null: false, default: 'api_call'
      t.string :endpoint
      t.text :request_body
      t.text :response_body
      t.integer :status_code
      t.string :environment
      t.timestamps
    end
    add_index :fbr_logs, :created_at
    add_index :fbr_logs, :log_type

    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.json :metadata, default: {}
      t.string :ip_address
      t.timestamps
    end
    add_index :audit_logs, [:auditable_type, :auditable_id]

    create_table :invoice_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :buyer_name
      t.string :buyer_ntn
      t.string :buyer_province, default: 'Punjab'
      t.text :buyer_address
      t.string :buyer_registration_type, default: 'Registered'
      t.bigint :buyer_company_id
      t.json :items_data, default: []
      t.timestamps
    end
    add_index :invoice_templates, [:user_id, :name]

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.string :notification_type, default: 'info'
      t.boolean :read, default: false, null: false
      t.string :link_path
      t.timestamps
    end
    add_index :notifications, [:user_id, :read]

    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :secret
      t.string :events, array: true, default: []
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_reference :invoices, :original_invoice, foreign_key: { to_table: :invoices }, index: true
    add_column :invoices, :qr_code_data, :text
    add_column :users, :seller_province, :string, default: 'Punjab'
    add_column :users, :approved, :boolean, default: false, null: false
    add_column :users, :onboarding_step, :integer, default: 0, null: false
    add_column :fbr_configurations, :token_ciphertext, :text

    User.update_all(approved: true) if table_exists?(:users)
  end
end
