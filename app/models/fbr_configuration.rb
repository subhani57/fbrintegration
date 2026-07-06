# app/models/fbr_configuration.rb
class FbrConfiguration < ApplicationRecord
  include EncryptedToken

  ENVIRONMENTS = %w[sandbox production].freeze

  belongs_to :user

  validates :environment, presence: true, inclusion: { in: ENVIRONMENTS }
  validates :environment, uniqueness: { scope: :user_id }
  validates :user_id, presence: true

  scope :sandbox, -> { where(environment: 'sandbox') }
  scope :production, -> { where(environment: 'production') }
  scope :with_token, -> {
    where("COALESCE(NULLIF(TRIM(token_ciphertext), ''), NULLIF(TRIM(token), '')) IS NOT NULL")
  }

  before_validation :ensure_active
  validate :token_not_expired, if: -> { token_expires_at.present? && token.present? }

  def security_token
    token
  end

  def integration_status
    token_configured? ? 'active' : 'inactive'
  end

  def ready?
    token_configured? && !token_expired?
  end

  def token_expired?
    token_expires_at.present? && token_expires_at < Time.current
  end

  def taxpayer_token_locked?
    token_configured?
  end

  def self.indexed_for_user(user)
    user.fbr_configurations.load unless user.fbr_configurations.loaded?
    configs = user.fbr_configurations.index_by(&:environment)

    ENVIRONMENTS.index_with do |environment|
      configs[environment] || user.fbr_configurations.build(environment: environment, active: true)
    end
  end

  private

  def ensure_active
    self.active = true
  end

  def token_not_expired
    errors.add(:token, 'has expired') if token_expired?
  end
end
