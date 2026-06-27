# frozen_string_literal: true

class InvoicesController < ApplicationController
  include InvoiceGuard
  include FbrSubmissionGuard

  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer_portal!
  before_action :ensure_taxpayer!, only: [:new, :create, :edit, :update, :destroy, :submit, :validate, :bulk_submit, :cancel, :save_template]
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :submit, :validate, :status, :download_pdf, :download_xml, :cancel, :save_template, :sync_from_iris, :mark_cancelled_on_iris]
  before_action :load_buyer_companies, only: [:new, :create, :edit, :update]
  before_action :load_submitted_invoices, only: [:new, :create, :edit, :update]
  before_action :authorize_invoice!, only: [:show, :edit, :update, :destroy, :submit, :validate, :status, :cancel, :save_template, :sync_from_iris, :mark_cancelled_on_iris]
  before_action :ensure_editable, only: [:edit, :update, :destroy]
  before_action :ensure_fbr_submission_allowed!, only: [:submit, :validate]

  def index
    per_page = params[:per].to_i
    per_page = 25 if per_page <= 0
    per_page = [per_page, 100].min

    @invoices = policy_scope(Invoice)
      .order(invoice_date: :desc, created_at: :desc)

    if params[:status].present?
      @invoices = @invoices.where(status: params[:status])
    end

    if params[:q].present?
      q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
      @invoices = @invoices.where(
        <<~SQL.squish,
          invoices.invoice_number ILIKE :q
          OR invoices.pdf_invoice_number ILIKE :q
          OR invoices.buyer_name ILIKE :q
          OR invoices.buyer_ntn ILIKE :q
          OR invoices.fbr_invoice_id ILIKE :q
        SQL
        q: q
      )
    end

    @invoices = @invoices.page(params[:page]).per(per_page)

    respond_to do |format|
      format.html
      format.json { render json: @invoices }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        pdf_data = @invoice.generate_pdf
        send_data pdf_data,
          filename: "invoice-#{@invoice.invoice_number}.pdf",
          type: 'application/pdf',
          disposition: 'inline'
      end
      format.json { render json: @invoice }
    end
  end

  def new
    @invoice = current_user.invoices.new(
      invoice_date: Date.today,
      invoice_type: 'Sale Invoice',
      scenario_id: Invoice::DEFAULT_SCENARIO_ID,
      buyer_province: Company::DEFAULT_PROVINCE,
      buyer_registration_type: Invoice::DEFAULT_BUYER_REGISTRATION_TYPE,
      pdf_invoice_number: Invoice.next_sequence_number_for(current_user)
    )
    @invoice.items.build
    apply_seller_defaults(@invoice)
    apply_default_buyer_company(@invoice)
    apply_template_if_requested(@invoice)
  end

  def create
    @invoice = current_user.invoices.new(invoice_params)
    authorize @invoice

    if @invoice.save
      AuditLog.record!(user: current_user, action: 'invoice.created', auditable: @invoice, request: request)
      redirect_to @invoice, notice: 'Invoice created successfully.'
    else
      @invoice.items.build if @invoice.items.empty?
      load_buyer_companies
      load_submitted_invoices
      flash.now[:alert] = @invoice.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @invoice.scenario_id = Invoice::DEFAULT_SCENARIO_ID if @invoice.scenario_id.blank?
    @invoice.items.build if @invoice.items.empty?
    load_buyer_companies
    load_submitted_invoices
  end

  def update
    if @invoice.update(invoice_params)
      AuditLog.record!(user: current_user, action: 'invoice.updated', auditable: @invoice, request: request)
      redirect_to @invoice, notice: 'Invoice updated successfully.'
    else
      load_buyer_companies
      load_submitted_invoices
      flash.now[:alert] = 'Failed to update invoice. Please check the form for errors.'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to invoices_url, notice: 'Invoice deleted successfully.'
  end

  def submit
    if @invoice.submitting? && @invoice.fbr_invoice_id.blank?
      FbrSubmissionJob.perform_later(@invoice.id)
      redirect_to @invoice, notice: 'Retrying FBR submission. This page will update automatically.'
      return
    end

    if @invoice.submitting? || @invoice.validating?
      redirect_to @invoice, notice: 'Invoice is still being processed. This page will update automatically.'
      return
    end

    unless @invoice.draft? || @invoice.validated? || @invoice.failed?
      redirect_to @invoice, alert: 'This invoice cannot be submitted in its current state.'
      return
    end

    @invoice.submit_to_fbr! if @invoice.may_submit_to_fbr?
    AuditLog.record!(user: current_user, action: 'invoice.submit_queued', auditable: @invoice, request: request)
    redirect_to @invoice, notice: 'Invoice queued for FBR submission. This page will update automatically.'
  rescue AASM::InvalidTransition => e
    redirect_to @invoice, alert: "Error: #{e.message}"
  end

  def validate
    if @invoice.validating? && !@invoice.validated?
      FbrValidationJob.perform_later(@invoice.id)
      redirect_to @invoice, notice: 'Retrying FBR validation. This page will update automatically.'
      return
    end

    if @invoice.submitting? || @invoice.validating?
      redirect_to @invoice, notice: 'Invoice is still being processed. This page will update automatically.'
      return
    end

    @invoice.validate_invoice! if @invoice.may_validate_invoice?
    AuditLog.record!(user: current_user, action: 'invoice.validate_queued', auditable: @invoice, request: request)
    redirect_to @invoice, notice: 'Invoice validation queued. This page will update automatically.'
  rescue AASM::InvalidTransition
    service = Fbr::ApiService.new(current_user, current_user.default_fbr_environment.to_sym)
    result = service.validate_invoice(@invoice)
    if result[:success]
      @invoice.safely_mark_validated!
      redirect_to @invoice, notice: 'Invoice validated successfully.'
    else
      @invoice.update(error_message: result[:error_message], fbr_status: 'failed')
      redirect_to @invoice, alert: "Validation failed: #{result[:error_message]}"
    end
  end

  def status
    recover_stuck_processing! if params[:recover] == "1"

    render json: {
      status: @invoice.status,
      fbr_status: @invoice.fbr_status,
      fbr_invoice_id: @invoice.fbr_invoice_id,
      error_message: @invoice.error_message
    }
  end

  def cancel
    if @invoice.may_cancel?
      @invoice.cancel!
      AuditLog.record!(user: current_user, action: 'invoice.cancelled', auditable: @invoice, request: request)
      redirect_to @invoice, notice: 'Invoice cancelled.'
    else
      redirect_to @invoice, alert: 'This invoice cannot be cancelled.'
    end
  end

  def sync_from_iris
    unless @invoice.fbr_invoice_id.present?
      redirect_to @invoice, alert: 'No FBR invoice number to sync.'
      return
    end

    result = Fbr::IrisInvoiceService.new(current_user).sync_invoice!(@invoice)
    if result[:success]
      notice = result[:notice].presence || "Synced from IRIS (#{result[:source]})."
      redirect_to @invoice, notice: notice
    elsif result[:api_unavailable]
      redirect_to @invoice, alert: result[:error_message]
    else
      redirect_to @invoice, alert: result[:error_message]
    end
  end

  def mark_cancelled_on_iris
    @invoice.apply_iris_cancellation!(message: 'Cancelled on FBR IRIS (confirmed manually).')
    AuditLog.record!(user: current_user, action: 'invoice.iris_cancelled', auditable: @invoice, request: request)
    redirect_to @invoice, notice: 'Invoice marked as cancelled on IRIS.'
  end

  def save_template
    name = params[:template_name].to_s.strip
    if name.blank?
      redirect_to @invoice, alert: 'Template name is required.'
      return
    end

    template = InvoiceTemplate.capture_from_invoice(@invoice, name: name)
    redirect_to invoice_templates_path, notice: "Template \"#{template.name}\" saved."
  end

  def bulk_submit
    invoice_ids = params[:invoice_ids]

    unless invoice_ids.present?
      redirect_back fallback_location: invoices_path, alert: 'No invoices selected.'
      return
    end

    current_user.fbr_configurations.load

    if (reason = Fbr::EnvironmentGuard.submission_blocked_reason(current_user))
      redirect_back fallback_location: invoices_path, alert: reason
      return
    end

    invoices = current_user.invoices.where(id: invoice_ids, status: %w[draft validated failed])
    queued_count = 0
    skipped_count = 0

    invoices.find_each do |invoice|
      unless invoice.draft? || invoice.validated? || invoice.failed?
        skipped_count += 1
        next
      end

      if Fbr::EnvironmentGuard.submission_blocked_reason(current_user, invoice: invoice)
        skipped_count += 1
        next
      end

      invoice.submit_to_fbr! if invoice.may_submit_to_fbr?
      queued_count += 1
    end

    notice = "#{queued_count} invoice(s) queued for FBR submission."
    notice += " #{skipped_count} skipped." if skipped_count.positive?

    redirect_back fallback_location: invoices_path, notice: notice
  end

  def download_pdf
    pdf_data = @invoice.generate_pdf
    send_data pdf_data,
      filename: "invoice-#{@invoice.invoice_number}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
  end

  def download_xml
    send_data @invoice.to_json,
      filename: "invoice-#{@invoice.invoice_number}.json",
      type: 'application/json',
      disposition: 'attachment'
  end

  private

  def set_invoice
    @invoice = current_user.invoices.includes(:items).find(params[:id])
  end

  def recover_stuck_processing!
    return unless @invoice.validating? || @invoice.submitting?
    return if @invoice.updated_at > 15.seconds.ago

    Rails.cache.fetch("invoice_status_recover:#{@invoice.id}", expires_in: 2.minutes) do
      if @invoice.validating?
        FbrValidationJob.perform_later(@invoice.id)
      elsif @invoice.submitting?
        FbrSubmissionJob.perform_later(@invoice.id)
      end
      true
    end

    @invoice.reload
  end

  def authorize_invoice!
    authorize @invoice
  end

  def ensure_editable
    return unless fbr_locked?(@invoice)

    redirect_to @invoice, alert: 'Submitted invoices cannot be modified.'
  end

  def invoice_params
    params.require(:invoice).permit(
      :invoice_date, :invoice_type, :original_invoice_id, :pdf_invoice_number,
      :seller_ntn, :seller_name, :seller_province, :seller_address,
      :buyer_ntn, :buyer_name, :buyer_province, :buyer_address,
      :buyer_registration_type, :buyer_company_id, :scenario_id,
      items_attributes: [
        :id, :_destroy, :hs_code, :description, :quantity,
        :uom, :unit_price, :tax_rate, :sale_type, :sro_schedule_no,
        :sales_tax, :total_value
      ]
    )
  end

  def apply_seller_defaults(invoice)
    invoice.seller_name = current_user.business_name.presence || current_user.email
    invoice.seller_ntn = current_user.ntn_cnic
    invoice.seller_province = current_user.seller_province.presence || Company::DEFAULT_PROVINCE
    invoice.seller_address = current_user.address.to_s.presence || 'Seller Address'
  end

  def load_buyer_companies
    @companies = current_user.companies.ordered
    @selected_buyer_company_id = resolve_selected_buyer_company_id
    @invoice_templates = current_user.invoice_templates.ordered
  end

  def load_submitted_invoices
    @submitted_invoices = current_user.invoices.where.not(fbr_invoice_id: nil).order(invoice_date: :desc).limit(50)
  end

  def apply_template_if_requested(invoice)
    template = current_user.invoice_templates.find_by(id: params[:template_id])
    template&.apply_to_invoice(invoice)
  end

  def find_default_buyer_company
    last_invoice = current_user.invoices.order(created_at: :desc).first
    return nil unless last_invoice

    if last_invoice.buyer_company_id.present?
      return current_user.companies.find_by(id: last_invoice.buyer_company_id)
    end

    return nil if last_invoice.buyer_ntn.blank?

    current_user.companies.find_by(ntn: last_invoice.buyer_ntn)
  end

  def apply_default_buyer_company(invoice)
    company = find_default_buyer_company
    return unless company

    @selected_buyer_company_id = company.id
    company.apply_to_invoice(invoice)
  end

  def resolve_selected_buyer_company_id
    return @invoice.buyer_company_id.to_s if @invoice&.buyer_company_id.present?

    find_default_buyer_company&.id&.to_s
  end
end
