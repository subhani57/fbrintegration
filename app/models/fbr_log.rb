# frozen_string_literal: true

class FbrLog < ApplicationRecord
  belongs_to :user
  belongs_to :invoice, optional: true

  validates :log_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :older_than, ->(days) { where('created_at < ?', days.days.ago) }
  scope :visible_in_admin_portal, -> {
    where("fbr_logs.environment IS DISTINCT FROM ?", 'sandbox')
      .where(
        "fbr_logs.invoice_id IS NULL OR fbr_logs.invoice_id NOT IN (?)",
        Invoice.sandbox_invoices.select(:id)
      )
  }

  def self.cleanup!(days: 90)
    older_than(days).delete_all
  end
end
