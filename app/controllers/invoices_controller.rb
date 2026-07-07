# frozen_string_literal: true

class InvoicesController < ApplicationController
  include FbrSubmissionGuard
  include InvoiceRecordLoading
  include InvoiceExcelExportable

  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer_portal!
  before_action :ensure_taxpayer!, only: [:new, :create, :edit, :update, :destroy, :submit, :validate, :bulk_submit, :cancel, :save_template]
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :submit, :validate, :status, :download_pdf, :cancel, :save_template, :sync_from_iris, :mark_cancelled_on_iris]
  before_action :load_buyer_companies, only: [:new, :create, :edit, :update]
  before_action :load_submitted_invoices, only: [:new, :create, :edit, :update]
  before_action :authorize_invoice!, only: [:show, :edit, :update, :destroy, :submit, :validate, :status, :cancel, :save_template, :sync_from_iris, :mark_cancelled_on_iris]
  before_action :ensure_editable, only: [:edit, :update, :destroy]
  before_action :ensure_fbr_submission_allowed!, only: [:submit, :validate]

  def index
    per_page = params[:per].to_i
    per_page = 25 if per_page <= 0
    per_page = [per_page, 100].min

    scope = invoice_list_scope

    respond_to do |format|
      format.html do
        assign_export_dates
        @invoices = scope.page(params[:page]).per(per_page)
      end
      format.xlsx do
        dates = export_date_range_or_redirect(invoices_path)
        return unless dates

        start_date, end_date = dates
        send_data Invoices::ExcelExporter.new(invoice_list_scope).to_stream,
                  filename: invoice_export_filename('invoices', start_date, end_date),
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment'
      end
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
    end
  end

  def new
    @invoice = portal_user.invoices.new(
      invoice_date: Date.today,
      invoice_type: 'Sale Invoice',
      scenario_id: Invoice::DEFAULT_SCENARIO_ID,
      buyer_province: Company::DEFAULT_PROVINCE,
      buyer_registration_type: Invoice::DEFAULT_BUYER_REGISTRATION_TYPE,
      pdf_invoice_number: Invoice.next_sequence_number_for(portal_user)
    )
    @invoice.items.build
    apply_seller_defaults(@invoice)
    apply_default_buyer_company(@invoice)
    apply_template_if_requested(@invoice)
  end

  def create
    @invoice = portal_user.invoices.new(invoice_params)
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
      Fbr::JobRunner.enqueue(FbrSubmissionJob, @invoice.id)
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
    redirect_to @invoice, notice: 'Submitting to FBR. This page will update automatically.'
  rescue AASM::InvalidTransition => e
    redirect_to @invoice, alert: "Error: #{e.message}"
  end

  def validate
    if @invoice.validating? && !@invoice.validated?
      run_fbr_job_now!
      redirect_to @invoice, notice: 'Retrying FBR validation. This page will update automatically.'
      return
    end

    if @invoice.submitting? || @invoice.validating?
      redirect_to @invoice, notice: 'Invoice is still being processed. This page will update automatically.'
      return
    end

    @invoice.validate_invoice! if @invoice.may_validate_invoice?
    AuditLog.record!(user: current_user, action: 'invoice.validate_queued', auditable: @invoice, request: request)
    redirect_to @invoice, notice: 'Validating with FBR. This page will update automatically.'
  rescue AASM::InvalidTransition
    service = Fbr::ApiService.new(portal_user, portal_user.default_fbr_environment.to_sym)
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
    authorize @invoice, :sync_from_iris?

    unless @invoice.fbr_invoice_id.present?
      redirect_to @invoice, alert: 'No FBR invoice number to sync.'
      return
    end

    result = Fbr::IrisInvoiceService.new(portal_user).sync_invoice!(@invoice)
    if result[:success]
      notice = result[:notice].presence || "Synced from IRIS (#{result[:source]})."
      redirect_to @invoice, notice: notice
    else
      redirect_to @invoice, alert: result[:error_message]
    end
  rescue Pundit::NotAuthorizedError
    redirect_to @invoice, alert: 'You are not authorized to sync this invoice.'
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

    portal_user.fbr_configurations.load

    if (reason = Fbr::EnvironmentGuard.submission_blocked_reason(portal_user))
      redirect_back fallback_location: invoices_path, alert: reason
      return
    end

    invoices = portal_user.invoices.where(id: invoice_ids, status: %w[draft validated failed])
    queued_count = 0
    skipped_count = 0

    invoices.find_each do |invoice|
      unless invoice.draft? || invoice.validated? || invoice.failed?
        skipped_count += 1
        next
      end

      if Fbr::EnvironmentGuard.submission_blocked_reason(portal_user, invoice: invoice)
        skipped_count += 1
        next
      end

      next unless invoice.may_submit_to_fbr?

      invoice.submit_to_fbr!
      queued_count += 1
    rescue AASM::InvalidTransition
      skipped_count += 1
    end

    notice = "#{queued_count} invoice(s) submitted to FBR."
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

  private

  def set_invoice
    @invoice = find_portal_invoice(params[:id])
    ActiveRecord::Associations::Preloader.new(records: [@invoice], associations: :user).call unless @invoice.association(:user).loaded?
  end

  def recover_stuck_processing!
    return unless @invoice.validating? || @invoice.submitting?
    return if @invoice.updated_at > 15.seconds.ago && params[:recover] != "1"

    Rails.cache.fetch("invoice_status_recover:#{@invoice.id}", expires_in: 2.minutes) do
      run_fbr_job_now!
      true
    end

    @invoice.reload
  end

  def run_fbr_job_now!
    if @invoice.validating?
      FbrValidationJob.perform_now(@invoice.id)
    elsif @invoice.submitting?
      FbrSubmissionJob.perform_now(@invoice.id)
    end
  end

  def authorize_invoice!
    authorize @invoice
  end

  def ensure_editable
    return unless @invoice.fbr_locked?

    redirect_to @invoice, alert: 'Submitted invoices cannot be modified.'
  end

  def invoice_params
    params.require(:invoice).permit(
      :invoice_date, :invoice_type, :original_invoice_id, :pdf_invoice_number, :po_number,
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
    invoice.seller_name = portal_user.business_name.presence || portal_user.email
    invoice.seller_ntn = portal_user.ntn_cnic
    invoice.seller_province = portal_user.seller_province.presence || Company::DEFAULT_PROVINCE
    invoice.seller_address = portal_user.address.to_s.presence || 'Seller Address'
  end

  def load_buyer_companies
    @companies = portal_user.companies.ordered
    @selected_buyer_company_id = resolve_selected_buyer_company_id
    @invoice_templates = portal_user.invoice_templates.ordered
  end

  def load_submitted_invoices
    @submitted_invoices = portal_user.invoices.where.not(fbr_invoice_id: nil).order(invoice_date: :desc).limit(50)
  end

  def apply_template_if_requested(invoice)
    template = portal_user.invoice_templates.find_by(id: params[:template_id])
    template&.apply_to_invoice(invoice)
  end

  def find_default_buyer_company
    last_invoice = portal_user.invoices.order(created_at: :desc).first
    return nil unless last_invoice

    if last_invoice.buyer_company_id.present?
      return portal_user.companies.find_by(id: last_invoice.buyer_company_id)
    end

    return nil if last_invoice.buyer_ntn.blank?

    portal_user.companies.find_by(ntn: last_invoice.buyer_ntn)
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

  def invoice_list_scope
    Invoices::ListScope.call(scope: policy_scope(Invoice), params: params, user: portal_user)
  end
end
