# app/models/user.rb
class User < ApplicationRecord
  ROLES = %w[admin taxpayer viewer accountant].freeze

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
  has_many :subscription_payments, dependent: :destroy
  belongs_to :subscription_plan, optional: true
  has_many :api_keys, dependent: :destroy
  has_many :support_tickets, dependent: :destroy
  has_many :recurring_invoices, dependent: :destroy
  has_many :connector_configs, dependent: :destroy
  has_many :buyer_verification_caches, dependent: :destroy
  has_many :accountant_clients, foreign_key: :accountant_id, dependent: :destroy
  has_many :clients, through: :accountant_clients, source: :client
  has_many :accountant_assignments, class_name: 'AccountantClient', foreign_key: :client_id, dependent: :destroy
  has_many :accountants, through: :accountant_assignments, source: :accountant

  MONTHLY_SUBSCRIPTION_FEE = 1000

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :preferred_fbr_environment, inclusion: { in: FbrConfiguration::ENVIRONMENTS }
  validates :seller_province, presence: true, if: -> { taxpayer? && ntn_cnic.present? }
  validate :preferred_production_environment_requirements

  scope :taxpayers, -> { where(role: 'taxpayer') }
  scope :admins, -> { where(role: 'admin') }
  scope :subscription_expired, -> { taxpayers.where('subscription_active_until IS NULL OR subscription_active_until < ?', Date.current) }
  scope :subscription_active, -> { taxpayers.where('subscription_active_until >= ?', Date.current) }
  scope :subscription_expiring_soon, -> {
    taxpayers.where(subscription_active_until: Date.current..Date.current + Subscriptions::Manager::EXPIRING_SOON_DAYS.days)
  }

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

  def accountant?
    role == 'accountant'
  end

  def effective_plan
    subscription_plan || SubscriptionPlan.default
  end

  def plan_feature?(key)
    effective_plan&.feature?(key) || false
  end

  def monthly_subscription_fee
    effective_plan&.monthly_fee || MONTHLY_SUBSCRIPTION_FEE
  end

  def configuration_for(environment)
    env = environment.to_s
    if fbr_configurations.loaded?
      fbr_configurations.find { |config| config.environment == env }
    else
      fbr_configurations.find_by(environment: env)
    end
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
    return true if accountant?
    taxpayer? && subscription_active?
  end

  def can_access_taxpayer_portal?
    taxpayer? || viewer? || accountant?
  end

  def subscription_active?
    return true unless taxpayer?

    subscription_active_until.present? && subscription_active_until >= Date.current
  end

  def subscription_expired?
    taxpayer? && !subscription_active?
  end

  def subscription_days_remaining
    return 0 unless subscription_active_until.present? && subscription_active?

    (subscription_active_until - Date.current).to_i
  end

  def subscription_expiring_soon?
    subscription_active? && subscription_days_remaining <= Subscriptions::Manager::EXPIRING_SOON_DAYS
  end

  def subscription_never_paid?
    taxpayer? && !subscription_payments.exists?
  end

  def subscription_status
    return :not_required unless taxpayer?
    return :never_paid if subscription_active_until.nil?
    return :expired if subscription_expired?
    return :expiring_soon if subscription_expiring_soon?

    :active
  end

  def subscription_status_label
    case subscription_status
    when :not_required then 'Not required'
    when :never_paid then 'Never paid'
    when :expired
      if subscription_active_until.present?
        "Expired #{subscription_active_until.strftime('%d %b %Y')}"
      else
        'Inactive'
      end
    when :expiring_soon then "Expires in #{subscription_days_remaining} day(s)"
    else "Active until #{subscription_active_until.strftime('%d %b %Y')}"
    end
  end

  def default_subscription_extension_date
    Subscriptions::Manager.resolve_active_until(self, period: 1)
  end

  def record_subscription_payment!(active_until:, recorded_by:, amount: nil, notes: nil, period_months: nil)
    Subscriptions::Manager.record_payment!(
      user: self,
      active_until: active_until,
      recorded_by: recorded_by,
      amount: amount,
      notes: notes,
      period_months: period_months
    )
  end

  def extend_subscription!(recorded_by:, months: 1)
    Subscriptions::Manager.extend!(user: self, recorded_by: recorded_by, months: months)
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
