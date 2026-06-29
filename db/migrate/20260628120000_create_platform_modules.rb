# frozen_string_literal: true

class CreatePlatformModules < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_plans do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.decimal :monthly_fee, precision: 10, scale: 2, null: false, default: 1000
      t.integer :invoice_limit
      t.json :features, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :subscription_plans, :slug, unique: true

    add_reference :users, :subscription_plan, foreign_key: true
    add_column :users, :phone, :string
    add_column :users, :sms_notifications, :boolean, default: false, null: false
    add_column :users, :whatsapp_notifications, :boolean, default: false, null: false

    add_column :subscription_payments, :receipt_number, :string
    add_index :subscription_payments, :receipt_number, unique: true

    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.datetime :last_used_at
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true

    create_table :support_tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assigned_admin, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.text :body, null: false
      t.string :status, null: false, default: 'open'
      t.string :priority, null: false, default: 'normal'
      t.timestamps
    end
    add_index :support_tickets, :status

    create_table :support_ticket_replies do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.boolean :staff_reply, null: false, default: false
      t.timestamps
    end

    create_table :recurring_invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.references :invoice_template, foreign_key: true
      t.references :buyer_company, foreign_key: { to_table: :companies }
      t.string :name, null: false
      t.string :frequency, null: false, default: 'monthly'
      t.date :next_run_on, null: false
      t.date :last_run_on
      t.boolean :active, null: false, default: true
      t.json :template_data, null: false, default: {}
      t.timestamps
    end
    add_index :recurring_invoices, [:user_id, :active]

    create_table :accountant_clients do |t|
      t.references :accountant, null: false, foreign_key: { to_table: :users }
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :accountant_clients, [:accountant_id, :client_id], unique: true

    create_table :buyer_verification_caches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ntn, null: false
      t.string :registration_type
      t.string :atl_status
      t.boolean :registered, default: false
      t.json :response_data, default: {}
      t.date :verified_on, null: false
      t.timestamps
    end
    add_index :buyer_verification_caches, [:user_id, :ntn, :verified_on], unique: true, name: 'index_buyer_verifications_on_user_ntn_date'

    create_table :connector_configs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :name, null: false
      t.json :settings, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :connector_configs, [:user_id, :provider]

    add_column :companies, :atl_status, :string
    add_column :companies, :atl_verified_at, :datetime
    add_column :companies, :fbr_registration_type, :string

    add_index :audit_logs, [:action, :created_at]
    add_index :audit_logs, :created_at
  end
end
