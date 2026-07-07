# frozen_string_literal: true

class SubscriptionPayment < ApplicationRecord
  STATUSES = %w[pending paid].freeze

  belongs_to :user
  belongs_to :recorded_by, class_name: 'User'
  has_many :line_items, class_name: 'SubscriptionPaymentLineItem', dependent: :destroy

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :active_until, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :amount_matches_line_items, if: -> { line_items.any? }

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }

  before_create :assign_receipt_number

  def pending?
    status == 'pending'
  end

  def paid?
    status == 'paid'
  end

  def status_label
    pending? ? 'Unpaid' : 'Paid'
  end

  private

  def amount_matches_line_items
    expected = line_items.sum(&:amount)
    return if (amount.to_f - expected).abs < 0.01

    errors.add(:amount, 'must match the sum of line items')
  end

  def assign_receipt_number
    self.receipt_number ||= "RCP-#{Date.current.strftime('%Y%m')}-#{SecureRandom.hex(3).upcase}"
  end
end
