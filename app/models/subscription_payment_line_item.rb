# frozen_string_literal: true

class SubscriptionPaymentLineItem < ApplicationRecord
  belongs_to :subscription_payment

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  default_scope { order(:position, :id) }
end
