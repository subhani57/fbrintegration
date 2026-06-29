# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_28_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accountant_clients", force: :cascade do |t|
    t.bigint "accountant_id", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accountant_id", "client_id"], name: "index_accountant_clients_on_accountant_id_and_client_id", unique: true
    t.index ["accountant_id"], name: "index_accountant_clients_on_accountant_id"
    t.index ["client_id"], name: "index_accountant_clients_on_client_id"
  end

  create_table "api_keys", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.json "metadata", default: {}
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["action", "created_at"], name: "index_audit_logs_on_action_and_created_at"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "business_scenario_mappings", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "business_nature", null: false
    t.datetime "created_at", null: false
    t.string "scenario_ids", default: [], array: true
    t.string "sector", null: false
    t.datetime "updated_at", null: false
    t.index ["business_nature", "sector"], name: "index_business_scenario_mappings_on_business_nature_and_sector", unique: true
  end

  create_table "buyer_verification_caches", force: :cascade do |t|
    t.string "atl_status"
    t.datetime "created_at", null: false
    t.string "ntn", null: false
    t.boolean "registered", default: false
    t.string "registration_type"
    t.json "response_data", default: {}
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.date "verified_on", null: false
    t.index ["user_id", "ntn", "verified_on"], name: "index_buyer_verifications_on_user_ntn_date", unique: true
    t.index ["user_id"], name: "index_buyer_verification_caches_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.text "address"
    t.string "atl_status"
    t.datetime "atl_verified_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "fbr_registration_type"
    t.string "name", null: false
    t.string "ntn", null: false
    t.string "phone"
    t.string "province", default: "Punjab", null: false
    t.string "registration_type", default: "Registered", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_companies_on_user_id_and_name"
    t.index ["user_id", "ntn"], name: "index_companies_on_user_id_and_ntn", unique: true
    t.index ["user_id"], name: "index_companies_on_user_id"
  end

  create_table "connector_configs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.json "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "provider"], name: "index_connector_configs_on_user_id_and_provider"
    t.index ["user_id"], name: "index_connector_configs_on_user_id"
  end

  create_table "fbr_configurations", force: :cascade do |t|
    t.boolean "active", default: false
    t.string "api_key"
    t.datetime "created_at", null: false
    t.string "environment", null: false
    t.string "token"
    t.text "token_ciphertext"
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["environment", "user_id"], name: "index_fbr_configurations_on_environment_and_user_id", unique: true
    t.index ["user_id", "environment"], name: "index_fbr_configurations_on_user_id_and_environment", unique: true
    t.index ["user_id"], name: "index_fbr_configurations_on_user_id"
  end

  create_table "fbr_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "environment"
    t.bigint "invoice_id"
    t.string "log_type", default: "api_call", null: false
    t.text "request_body"
    t.text "response_body"
    t.integer "status_code"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_fbr_logs_on_created_at"
    t.index ["invoice_id"], name: "index_fbr_logs_on_invoice_id"
    t.index ["log_type"], name: "index_fbr_logs_on_log_type"
    t.index ["user_id"], name: "index_fbr_logs_on_user_id"
  end

  create_table "fbr_scenarios", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.string "sale_type"
    t.string "scenario_id", null: false
    t.datetime "updated_at", null: false
    t.index ["scenario_id"], name: "index_fbr_scenarios_on_scenario_id", unique: true
  end

  create_table "invoice_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "hs_code"
    t.bigint "invoice_id"
    t.decimal "quantity", precision: 15, scale: 4
    t.string "sale_type"
    t.decimal "sales_tax", precision: 15, scale: 2
    t.string "sro_schedule_no"
    t.decimal "tax_rate", precision: 5, scale: 2
    t.decimal "total_value", precision: 15, scale: 2
    t.decimal "unit_price", precision: 15, scale: 2
    t.string "uom"
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoice_templates", force: :cascade do |t|
    t.text "buyer_address"
    t.bigint "buyer_company_id"
    t.string "buyer_name"
    t.string "buyer_ntn"
    t.string "buyer_province", default: "Punjab"
    t.string "buyer_registration_type", default: "Registered"
    t.datetime "created_at", null: false
    t.json "items_data", default: []
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_invoice_templates_on_user_id_and_name"
    t.index ["user_id"], name: "index_invoice_templates_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.text "buyer_address"
    t.bigint "buyer_company_id"
    t.string "buyer_name"
    t.string "buyer_ntn"
    t.string "buyer_province"
    t.string "buyer_registration_type"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "fbr_invoice_id"
    t.string "fbr_status"
    t.date "invoice_date"
    t.string "invoice_number"
    t.string "invoice_type"
    t.bigint "original_invoice_id"
    t.string "pdf_invoice_number"
    t.text "qr_code_data"
    t.json "response_data"
    t.integer "retry_count", default: 0
    t.string "scenario_id"
    t.text "seller_address"
    t.string "seller_name"
    t.string "seller_ntn"
    t.string "seller_province"
    t.string "sro_schedule_no"
    t.string "status"
    t.datetime "submitted_at"
    t.decimal "tax_amount", precision: 15, scale: 2
    t.json "test_data"
    t.decimal "total_amount", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["buyer_company_id"], name: "index_invoices_on_buyer_company_id"
    t.index ["fbr_invoice_id"], name: "index_invoices_on_fbr_invoice_id"
    t.index ["original_invoice_id"], name: "index_invoices_on_original_invoice_id"
    t.index ["scenario_id"], name: "index_invoices_on_scenario_id"
    t.index ["user_id", "invoice_number"], name: "index_invoices_on_user_id_and_invoice_number", unique: true
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "link_path"
    t.string "notification_type", default: "info"
    t.boolean "read", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "recurring_invoices", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "buyer_company_id"
    t.datetime "created_at", null: false
    t.string "frequency", default: "monthly", null: false
    t.bigint "invoice_template_id"
    t.date "last_run_on"
    t.string "name", null: false
    t.date "next_run_on", null: false
    t.json "template_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["buyer_company_id"], name: "index_recurring_invoices_on_buyer_company_id"
    t.index ["invoice_template_id"], name: "index_recurring_invoices_on_invoice_template_id"
    t.index ["user_id", "active"], name: "index_recurring_invoices_on_user_id_and_active"
    t.index ["user_id"], name: "index_recurring_invoices_on_user_id"
  end

  create_table "subscription_payments", force: :cascade do |t|
    t.date "active_until", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "1000.0", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "receipt_number"
    t.bigint "recorded_by_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["receipt_number"], name: "index_subscription_payments_on_receipt_number", unique: true
    t.index ["recorded_by_id"], name: "index_subscription_payments_on_recorded_by_id"
    t.index ["user_id", "created_at"], name: "index_subscription_payments_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_subscription_payments_on_user_id"
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.json "features", default: {}, null: false
    t.integer "invoice_limit"
    t.decimal "monthly_fee", precision: 10, scale: 2, default: "1000.0", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_subscription_plans_on_slug", unique: true
  end

  create_table "support_ticket_replies", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.boolean "staff_reply", default: false, null: false
    t.bigint "support_ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["support_ticket_id"], name: "index_support_ticket_replies_on_support_ticket_id"
    t.index ["user_id"], name: "index_support_ticket_replies_on_user_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "assigned_admin_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "priority", default: "normal", null: false
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["assigned_admin_id"], name: "index_support_tickets_on_assigned_admin_id"
    t.index ["status"], name: "index_support_tickets_on_status"
    t.index ["user_id"], name: "index_support_tickets_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "address"
    t.boolean "approved", default: false, null: false
    t.string "business_name"
    t.string "company_logo"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "ntn_cnic"
    t.integer "onboarding_step", default: 0, null: false
    t.string "phone"
    t.string "preferred_fbr_environment", default: "sandbox", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "taxpayer", null: false
    t.string "seller_province", default: "Punjab"
    t.integer "sign_in_count", default: 0, null: false
    t.boolean "sms_notifications", default: false, null: false
    t.date "subscription_active_until"
    t.bigint "subscription_plan_id"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.boolean "whatsapp_notifications", default: false, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["preferred_fbr_environment"], name: "index_users_on_preferred_fbr_environment"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["subscription_active_until"], name: "index_users_on_subscription_active_until"
    t.index ["subscription_plan_id"], name: "index_users_on_subscription_plan_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "events", default: [], array: true
    t.string "secret"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_webhooks_on_user_id"
  end

  add_foreign_key "accountant_clients", "users", column: "accountant_id"
  add_foreign_key "accountant_clients", "users", column: "client_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "buyer_verification_caches", "users"
  add_foreign_key "companies", "users"
  add_foreign_key "connector_configs", "users"
  add_foreign_key "fbr_configurations", "users"
  add_foreign_key "fbr_logs", "invoices"
  add_foreign_key "fbr_logs", "users"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_templates", "users"
  add_foreign_key "invoices", "companies", column: "buyer_company_id"
  add_foreign_key "invoices", "invoices", column: "original_invoice_id"
  add_foreign_key "invoices", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "recurring_invoices", "companies", column: "buyer_company_id"
  add_foreign_key "recurring_invoices", "invoice_templates"
  add_foreign_key "recurring_invoices", "users"
  add_foreign_key "subscription_payments", "users"
  add_foreign_key "subscription_payments", "users", column: "recorded_by_id"
  add_foreign_key "support_ticket_replies", "support_tickets"
  add_foreign_key "support_ticket_replies", "users"
  add_foreign_key "support_tickets", "users"
  add_foreign_key "support_tickets", "users", column: "assigned_admin_id"
  add_foreign_key "users", "subscription_plans"
  add_foreign_key "webhooks", "users"
end
