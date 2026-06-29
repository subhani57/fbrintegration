# Buyer companies saved per taxpayer (for invoice buyer details).
class Company < ApplicationRecord
  DEFAULT_PROVINCE = 'Punjab'.freeze
  DEFAULT_REGISTRATION_TYPE = 'Registered'.freeze

  belongs_to :user
  has_many :invoices, foreign_key: :buyer_company_id, dependent: :nullify, inverse_of: :buyer_company

  validates :name, presence: true
  validates :ntn, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :province, presence: true
  validates :registration_type, presence: true

  before_validation :apply_defaults

  scope :ordered, -> { order(:name) }

  def apply_to_invoice(invoice)
    invoice.buyer_company = self
    invoice.buyer_name = name
    invoice.buyer_ntn = ntn
    invoice.buyer_province = province
    invoice.buyer_registration_type = registration_type
    invoice.buyer_address = address
  end

  def apply_fbr_verification!(result)
    update!(
      atl_status: result[:atl_status],
      fbr_registration_type: result[:registration_type],
      atl_verified_at: Time.current
    )
  end

  def atl_verification_fresh?
    atl_verified_at.present? && atl_verified_at > 30.days.ago
  end

  private

  def apply_defaults
    self.province = DEFAULT_PROVINCE if province.blank?
    self.registration_type = DEFAULT_REGISTRATION_TYPE if registration_type.blank?
  end
end
