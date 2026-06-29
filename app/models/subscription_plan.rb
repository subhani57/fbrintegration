# frozen_string_literal: true

class SubscriptionPlan < ApplicationRecord
  SLUGS = %w[basic pro enterprise].freeze

  has_many :users, dependent: :nullify

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, inclusion: { in: SLUGS }
  validates :monthly_fee, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  def feature?(key)
    features.fetch(key.to_s, false)
  end

  def self.default
    find_by(slug: 'basic')
  end
end
