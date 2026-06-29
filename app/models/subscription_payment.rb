# frozen_string_literal: true

class SubscriptionPayment < ApplicationRecord
  belongs_to :user
  belongs_to :recorded_by, class_name: 'User'

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :active_until, presence: true

  scope :recent, -> { order(created_at: :desc) }

  before_create :assign_receipt_number

  private

  def assign_receipt_number
    self.receipt_number ||= "RCP-#{Date.current.strftime('%Y%m')}-#{SecureRandom.hex(3).upcase}"
  end
end
