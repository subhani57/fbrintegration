# app/models/user.rb
class User < ApplicationRecord
  ROLES = %w[admin taxpayer viewer].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :timeoutable

  has_many :invoices, dependent: :destroy
  has_many :companies, dependent: :destroy
  has_many :fbr_configurations, dependent: :destroy
  has_many :invoice_templates, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :fbr_logs, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :preferred_fbr_environment, inclusion: { in: FbrConfiguration::ENVIRONMENTS }
  validates :seller_province, presence: true, if: -> { taxpayer? && ntn_cnic.present? }
  validate :preferred_production_environment_requirements

  scope :taxpayers, -> { where(role: 'taxpayer') }
  scope :admins, -> { where(role: 'admin') }

  mount_uploader :company_logo, CompanyLogoUploader

  attr_accessor :remove_company_logo

  before_save :purge_company_logo_if_requested

  after_create :create_default_configuration

  def admin?
    role == 'admin'
  end

  def taxpayer?
    role == 'taxpayer'
  end

  def viewer?
    role == 'viewer'
  end

  def configuration_for(environment)
    env = environment.to_s
    if fbr_configurations.loaded?
      fbr_configurations.find { |config| config.environment == env }
    else
      fbr_configurations.find_by(environment: env)
    end
  end

  def active_configuration(environment = default_fbr_environment)
    configuration_for(environment)
  end

  def default_fbr_environment
    preferred_fbr_environment.presence || (Rails.env.production? ? 'production' : 'sandbox')
  end

  def can_submit_invoices?
    return false unless taxpayer?

    Fbr::EnvironmentGuard.submission_blocked_reason(self).nil?
  end

  def production_fbr_environment?
    Fbr::EnvironmentGuard.production?(self)
  end

  def can_manage_invoices?
    taxpayer?
  end

  def can_access_taxpayer_portal?
    taxpayer? || viewer?
  end

  def onboarding_complete?
    onboarding_step >= 3
  end

  def advance_onboarding!
    update!(onboarding_step: [onboarding_step + 1, 3].min)
  end

  private

  def create_default_configuration
    fbr_configurations.find_or_create_by!(environment: 'sandbox', user_id: id) do |config|
      config.active = true
    end
  end

  def preferred_production_environment_requirements
    return unless will_save_change_to_preferred_fbr_environment?
    return unless preferred_fbr_environment == 'production'

    reason = Fbr::EnvironmentGuard.switch_environment_blocked_reason(self, 'production')
    errors.add(:preferred_fbr_environment, reason) if reason.present?
  end

  def purge_company_logo_if_requested
    return unless ActiveModel::Type::Boolean.new.cast(remove_company_logo)

    company_logo.remove!
  end
end
