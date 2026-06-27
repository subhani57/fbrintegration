# frozen_string_literal: true

class Webhook < ApplicationRecord
  belongs_to :user

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  scope :active, -> { where(active: true) }

  def listens_to?(event)
    events.blank? || events.include?(event.to_s)
  end
end
