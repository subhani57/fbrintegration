# frozen_string_literal: true

class FbrLog < ApplicationRecord
  belongs_to :user
  belongs_to :invoice, optional: true

  validates :log_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :api_calls, -> { where(log_type: 'api_call') }
  scope :older_than, ->(days) { where('created_at < ?', days.days.ago) }

  def self.cleanup!(days: 90)
    older_than(days).delete_all
  end
end
