# app/models/invoice.rb
class Invoice < ApplicationRecord
  include AASM

  DEFAULT_SCENARIO_ID = 'SN001'.freeze
  DEFAULT_BUYER_REGISTRATION_TYPE = 'Registered'.freeze

  belongs_to :user
  belongs_to :buyer_company, class_name: 'Company', optional: true
  belongs_to :original_invoice, class_name: 'Invoice', optional: true
  has_many :credit_notes, class_name: 'Invoice', foreign_key: :original_invoice_id, dependent: :nullify
  has_many :items, class_name: 'InvoiceItem', dependent: :destroy
  has_many :fbr_logs, dependent: :destroy
  accepts_nested_attributes_for :items, reject_if: proc { |attributes| 
    attributes['description'].blank? && attributes['quantity'].blank? && attributes['unit_price'].blank?
  }, allow_destroy: true

  # Validations
  validates :invoice_date, presence: true
  validates :invoice_type, presence: true
  # Only validate buyer fields if not draft
  validates :buyer_name, presence: true, if: -> { status != 'draft' }
  validates :buyer_ntn, presence: true, if: -> { status != 'draft' }
  validates :buyer_province, presence: true, if: -> { status != 'draft' }
  validates :buyer_address, presence: true, if: -> { status != 'draft' }
  validates :buyer_registration_type, presence: true, if: -> { status != 'draft' }
  validate :buyer_company_must_belong_to_user, if: -> { buyer_company_id.present? }
  validate :original_invoice_required_for_debit_note, if: -> { invoice_type == 'Debit Note' }
  # Allow blank for draft invoices
  validates :total_amount, numericality: { greater_than: 0, allow_nil: true }
  validates :tax_amount, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  # State Machine
  aasm column: :status do
    state :draft, initial: true
    state :validating
    state :validated
    state :submitting
    state :submitted
    state :approved
    state :rejected
    state :failed
    state :cancelled

    event :validate_invoice do
      transitions from: [:draft, :failed], to: :validating, after_commit: :perform_validation
    end

    event :mark_validated do
      transitions from: [:validating, :draft, :failed], to: :validated
    end

    event :submit_to_fbr do
      transitions from: [:validated, :draft, :failed], to: :submitting, after_commit: :queue_fbr_submission
    end

    event :mark_submitted do
      transitions from: :submitting, to: :submitted, after: :generate_qr_code
    end

    event :approve do
      transitions from: :submitted, to: :approved
    end

    event :reject do
      transitions from: :submitted, to: :rejected
    end

    event :mark_failed do
      transitions from: [:validating, :submitting, :draft, :validated], to: :failed
    end

    event :cancel do
      transitions from: [:draft, :validated], to: :cancelled
    end
  end

  # Callbacks
  after_initialize :apply_fbr_defaults, if: :new_record?
  before_validation :apply_seller_from_user, on: :create
  before_validation :apply_buyer_from_company
  before_validation :apply_buyer_defaults
  before_validation :apply_fbr_defaults
  before_validation :generate_invoice_number, on: :create
  before_validation :assign_pdf_invoice_number, on: :create
  before_save :calculate_totals
  after_update_commit :broadcast_show_page_refresh_after_fbr_processing

  # Scopes
  scope :today, -> { where(invoice_date: Date.today) }
  scope :this_month, -> { where(invoice_date: Date.today.beginning_of_month..Date.today.end_of_month) }
  scope :submitted, -> { where(fbr_status: 'submitted') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_date_range, ->(start_date, end_date) { where(invoice_date: start_date..end_date) }

  # Class Methods
  def self.next_sequence_number_for(user, date: Date.today)
    return nil unless user

    date_prefix = date.strftime('%Y%m%d')
    pattern = "#{date_prefix}-%"

    numbers = user.invoices.where(
      "invoice_number LIKE :pattern OR pdf_invoice_number LIKE :pattern",
      pattern: pattern
    ).pluck(:invoice_number, :pdf_invoice_number).flatten.compact

    max_seq = numbers.filter_map do |num|
      next unless num.start_with?(date_prefix)

      suffix = num.delete_prefix("#{date_prefix}-")
      suffix.match?(/\A\d+\z/) ? suffix.to_i : nil
    end.max || 0

    "#{date_prefix}-#{format('%04d', max_seq + 1)}"
  end

  # Instance Methods
  def calculate_totals
    return if items.empty? || items.all? { |item| item.description.blank? && item.quantity.blank? }
    
    # Only calculate for items that are not marked for destruction and have data
    valid_items = items.reject { |item| 
      item.marked_for_destruction? || (item.description.blank? && item.quantity.blank?)
    }
    return if valid_items.empty?
    
    net_amount = valid_items.sum { |item| 
      (item.total_value || (item.quantity.to_f * item.unit_price.to_f)) 
    }
    tax_amount = valid_items.sum { |item| (item.sales_tax || 0) }

    self.tax_amount = tax_amount
    self.total_amount = net_amount + tax_amount
  end

  def generate_invoice_number
    return if invoice_number.present?

    self.invoice_number = self.class.next_sequence_number_for(user)
  end

  def assign_pdf_invoice_number
    return if pdf_invoice_number.present?

    self.pdf_invoice_number = self.class.next_sequence_number_for(user)
  end

  def pdf_display_number
    pdf_invoice_number.presence || invoice_number
  end

  def perform_validation
    FbrValidationJob.perform_later(id)
  end

  def queue_fbr_submission
    FbrSubmissionJob.perform_later(id)
  end


  def generate_qr_code
    return unless fbr_invoice_id.present?
    
    qr_data = {
      ver: "1.0",
      seller_ntn: seller_ntn || '0000000000000',
      buyer_ntn: buyer_ntn || '0000000000000',
      inv_num: fbr_invoice_id,
      inv_date: invoice_date.iso8601,
      total_amount: total_amount.to_s,
      tax_amount: tax_amount.to_s
    }.to_json

    begin
      qr = RQRCode::QRCode.new(qr_data)
      png = qr.as_png(size: 300, border_modules: 2)
      
      # Store QR code data if column exists, otherwise skip
      if respond_to?(:qr_code_data=)
        self.qr_code_data = Base64.strict_encode64(png.to_s)
        save!
      else
        AppLogger.info('invoice.qr_code_column_missing', invoice_id: id)
      end
    rescue => e
      AppLogger.error('invoice.qr_code_generation_failed', exception: e, invoice_id: id)
      # Don't fail invoice submission if QR code generation fails
    end
  end

  def generate_pdf
    PdfGenerator.new(self).generate
  end

  def iris_cancelled?
    cancelled? && fbr_status == 'cancelled'
  end

  def apply_iris_cancellation!(source_data: nil, message: nil)
    return true if iris_cancelled?

    attrs = {
      status: 'cancelled',
      fbr_status: 'cancelled',
      error_message: message.presence || 'Cancelled on FBR IRIS.'
    }

    if source_data.is_a?(Hash)
      attrs[:response_data] = (response_data || {}).merge(
        'iris_sync' => source_data,
        'iris_synced_at' => Time.current.iso8601,
        'iris_cancelled_at' => Time.current.iso8601
      )
    end

    update!(attrs)
    true
  end

  def fbr_qr_image_base64
    return nil unless response_data.is_a?(Hash)

    response_data['QRCode'] || response_data.dig('iris_sync', 'QRCode')
  end

  def iris_verification_url
    'https://iris.fbr.gov.pk'
  end

  def fbr_locked?
    fbr_status == 'submitted' || fbr_invoice_id.present? ||
      %w[submitted approved submitting].include?(status)
  end

  def debit_note?
    invoice_type == 'Debit Note'
  end

  def original_invoice_fbr_number
    original_invoice&.fbr_invoice_id
  end

  def broadcast_show_page_refresh_after_fbr_processing
    return unless saved_change_to_status?

    previous_status = status_before_last_save
    return unless %w[submitting validating].include?(previous_status)
    return if submitting? || validating?

    broadcast_refresh_later_to self
  end

  private

  def apply_fbr_defaults
    self.scenario_id = DEFAULT_SCENARIO_ID if scenario_id.blank?
    self.buyer_registration_type = DEFAULT_BUYER_REGISTRATION_TYPE if buyer_registration_type.blank?
  end

  def apply_buyer_defaults
    self.buyer_province = Company::DEFAULT_PROVINCE if buyer_province.blank?
    self.buyer_registration_type = DEFAULT_BUYER_REGISTRATION_TYPE if buyer_registration_type.blank?
  end

  def apply_buyer_from_company
    return if buyer_company_id.blank?

    company = buyer_company || user&.companies&.find_by(id: buyer_company_id)
    return unless company

    self.buyer_company = company
    self.buyer_name = company.name
    self.buyer_ntn = company.ntn
    self.buyer_province = company.province
    self.buyer_registration_type = company.registration_type
    self.buyer_address = company.address
  end

  def buyer_company_must_belong_to_user
    return if user.blank?
    return if user.companies.exists?(id: buyer_company_id)

    errors.add(:buyer_company_id, 'must be one of your saved companies')
  end

  def original_invoice_required_for_debit_note
    return if original_invoice_id.blank?

    original = user.invoices.find_by(id: original_invoice_id)
    if original.nil?
      errors.add(:original_invoice_id, 'must be one of your submitted invoices')
    elsif original.fbr_invoice_id.blank?
      errors.add(:original_invoice_id, 'must reference an invoice submitted to FBR')
    end
  end

  def clear_stale_fbr_error!
    return unless error_message.present? || fbr_status == 'failed'

    update!(error_message: nil, fbr_status: nil)
  end

  def apply_seller_from_user
    return unless user

    self.seller_name = user.business_name.presence || user.email if seller_name.blank?
    self.seller_ntn = user.ntn_cnic if seller_ntn.blank?
    self.seller_address = user.address.presence || 'Seller Address' if seller_address.blank?
    self.seller_province = user.seller_province.presence || Company::DEFAULT_PROVINCE if seller_province.blank?
  end

  public

  # Safe state transition helpers
  # These helpers make transitions idempotent and swallow InvalidTransition
  # so callers (controllers, jobs, console) can call them without raising
  # when the invoice is already in the target state.
  def safely_mark_validated!
    if validated?
      clear_stale_fbr_error!
      return true
    end
    if respond_to?(:may_mark_validated?) ? may_mark_validated? : !validated?
      mark_validated!
      clear_stale_fbr_error!
      true
    else
      AppLogger.info('invoice.validate_transition_skipped', invoice_id: id, status: status)
      false
    end
  rescue AASM::InvalidTransition => e
    AppLogger.info('invoice.validate_transition_invalid', invoice_id: id, message: e.message)
    false
  end

  def notify_submission_success!
    Notification.notify!(
      user,
      title: 'Invoice submitted to FBR',
      body: "#{invoice_number} was registered successfully.",
      notification_type: 'success',
      link_path: "/invoices/#{id}"
    )
    InvoiceMailer.submission_success(self).deliver_later
    Webhooks::Dispatcher.dispatch(user, 'invoice.submitted', invoice_webhook_payload)
  end

  def notify_submission_failed!
    Notification.notify!(
      user,
      title: 'FBR submission failed',
      body: "#{invoice_number}: #{error_message}",
      notification_type: 'danger',
      link_path: "/invoices/#{id}"
    )
    InvoiceMailer.submission_failed(self).deliver_later
    Webhooks::Dispatcher.dispatch(user, 'invoice.failed', invoice_webhook_payload.merge(error: error_message))
  end

  def invoice_webhook_payload
    {
      id: id,
      invoice_number: invoice_number,
      fbr_invoice_id: fbr_invoice_id,
      status: status,
      fbr_status: fbr_status,
      total_amount: total_amount.to_f,
      tax_amount: tax_amount.to_f
    }
  end
  
  # Submit to FBR API (called from job or sync controller path)
  def submit_to_fbr_api!(environment: nil)
    Fbr::EnvironmentGuard.ensure_submission_allowed!(user, invoice: self)

    env = (environment || user.default_fbr_environment).to_sym
    service = Fbr::ApiService.new(user, env)
    result = service.submit_invoice(self)
    
    if result[:success]
      stored_data = (result[:data] || {}).merge('submitted_environment' => env.to_s)
      update!(
        fbr_invoice_id: result[:fbr_invoice_id] || result[:invoice_number],
        response_data: stored_data,
        submitted_at: Time.current,
        error_message: nil,
        status: 'approved',
        fbr_status: 'submitted'
      )
      mark_submitted! if respond_to?(:mark_submitted!) && submitting?
      approve! if respond_to?(:approve!) && submitted?
      notify_submission_success!
      true
    else
      error_msg = result[:error_message] || 'Unknown error'
      update!(
        error_message: error_msg,
        response_data: result[:data],
        status: 'failed',
        fbr_status: 'failed'
      )
      mark_failed! if respond_to?(:mark_failed!) && (draft? || validated? || submitting? || validating?)
      notify_submission_failed!
      false
    end
  rescue => e
    AppLogger.error('invoice.fbr_submission_failed', exception: e, invoice_id: id, user_id: user_id)
    update!(
      error_message: e.message,
      fbr_status: 'failed'
    )
    # Mark as failed (state machine now allows from draft, validated, submitting, validating)
    mark_failed! if respond_to?(:mark_failed!) && (draft? || validated? || submitting? || validating?)
    false
  end
end