# app/models/invoice_item.rb
class InvoiceItem < ApplicationRecord
  DEFAULT_SALE_TYPE = 'Goods at standard rate (default)'.freeze
  DEFAULT_TAX_RATE = 18

  belongs_to :invoice

  after_initialize :apply_defaults, if: :new_record?
  before_validation :apply_defaults

  # Validations
  validates :description, presence: true, if: -> { invoice.present? && !invoice.draft? }
  validates :quantity, presence: true, numericality: { greater_than: 0 }, if: -> { invoice.present? && !invoice.draft? }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: -> { invoice.present? && !invoice.draft? }
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Callbacks
  before_save :calculate_totals

  # Computed fields
  def total_price
    (quantity.to_f * unit_price.to_f).round(2)
  end

  def tax_amount
    (total_price * (tax_rate.to_f / 100)).round(2)
  end

  def net_amount
    total_price - tax_amount
  end

  private

  def apply_defaults
    self.sale_type = DEFAULT_SALE_TYPE if sale_type.blank?
    self.tax_rate = DEFAULT_TAX_RATE if tax_rate.blank?
  end

  def calculate_totals
    return if quantity.blank? || unit_price.blank?
    # self.total_value = total_price
    # self.sales_tax = tax_amount
  end
end

