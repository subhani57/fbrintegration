# frozen_string_literal: true

class RecurringInvoice < ApplicationRecord
  FREQUENCIES = %w[weekly monthly quarterly yearly].freeze

  belongs_to :user
  belongs_to :invoice_template, optional: true
  belongs_to :buyer_company, class_name: 'Company', optional: true

  validates :name, :next_run_on, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :active, -> { where(active: true) }
  scope :due, -> { active.where('next_run_on <= ?', Date.current) }

  def run!
    invoice = user.invoices.new(
      invoice_date: Date.current,
      invoice_type: template_data['invoice_type'] || 'Sale Invoice',
      buyer_company: buyer_company
    )

    if invoice_template
      invoice_template.apply_to_invoice(invoice)
    elsif template_data.present?
      apply_template_data(invoice)
    end

    invoice.save!
    update!(last_run_on: Date.current, next_run_on: next_occurrence)
    invoice
  end

  def next_occurrence
    case frequency
    when 'weekly' then next_run_on + 1.week
    when 'monthly' then next_run_on + 1.month
    when 'quarterly' then next_run_on + 3.months
    when 'yearly' then next_run_on + 1.year
    else next_run_on + 1.month
    end
  end

  private

  def apply_template_data(invoice)
    invoice.assign_attributes(template_data.slice('buyer_name', 'buyer_ntn', 'buyer_province', 'buyer_address', 'buyer_registration_type'))
    Array(template_data['items']).each do |item|
      invoice.items.build(item.slice('hs_code', 'description', 'quantity', 'uom', 'unit_price', 'tax_rate', 'sale_type', 'sro_schedule_no'))
    end
  end
end
