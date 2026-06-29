# frozen_string_literal: true

class BuyerVerificationCache < ApplicationRecord
  self.table_name = 'buyer_verification_caches'

  belongs_to :user

  validates :ntn, :verified_on, presence: true

  scope :for_ntn, ->(ntn) { where(ntn: ntn.to_s.strip) }
  scope :fresh, -> { where('verified_on >= ?', 30.days.ago.to_date) }

  def self.store!(user:, ntn:, result:)
    find_or_initialize_by(user: user, ntn: ntn.to_s.strip, verified_on: Date.current).tap do |record|
      record.registration_type = result[:registration_type]
      record.atl_status = result[:atl_status]
      record.registered = result[:registered]
      record.response_data = result
      record.save!
    end
  end

  def atl_active?
    atl_status.to_s.downcase.include?('active')
  end
end
