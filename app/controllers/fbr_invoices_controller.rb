class FbrInvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer_portal!
  before_action :ensure_taxpayer!, only: [:sync_from_fbr]
  before_action :set_invoice, only: [:show, :download_pdf, :sync_from_fbr]

  def index
    @invoices = current_user.invoices
      .where.not(fbr_invoice_id: [nil, ''])
      .includes(:items)
      .order(submitted_at: :desc, updated_at: :desc)
      .page(params[:page])
      .per(20)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @invoices = @invoices.where(
        'fbr_invoice_id ILIKE :q OR invoice_number ILIKE :q OR buyer_name ILIKE :q',
        q: q
      )
    end

    @stats = {
      total: current_user.invoices.where.not(fbr_invoice_id: [nil, '']).count,
      this_month: current_user.invoices.where.not(fbr_invoice_id: [nil, ''])
        .where(submitted_at: Date.today.beginning_of_month..Date.today.end_of_month).count
    }
  end

  def lookup
    @fbr_number = params[:fbr_invoice_number].to_s.strip
    @result = Fbr::IrisInvoiceService.new(current_user).fetch(@fbr_number)

    if @result[:success]
      @local_invoice = @result[:local_invoice]
      @fbr_data = @result[:data]
      @source = @result[:source]
      @notice = @result[:notice]
      render :lookup
    else
      redirect_to fbr_invoices_path, alert: @result[:error_message]
    end
  end

  def show
  end

  def download_pdf
    unless @invoice.fbr_invoice_id.present?
      redirect_to @invoice, alert: 'This invoice is not registered on FBR yet.'
      return
    end

    pdf_data = @invoice.generate_pdf
    send_data pdf_data,
      filename: "fbr-invoice-#{@invoice.fbr_invoice_id}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
  end

  def sync_from_fbr
    unless @invoice.fbr_invoice_id.present?
      redirect_to @invoice, alert: 'No FBR invoice number to sync.'
      return
    end

    result = Fbr::IrisInvoiceService.new(current_user).sync_invoice!(@invoice)
    if result[:success]
      redirect_to fbr_invoice_path(@invoice),
                  notice: "Synced from FBR (#{result[:source]})."
    else
      redirect_to fbr_invoice_path(@invoice), alert: result[:error_message]
    end
  end

  private

  def set_invoice
    @invoice = current_user.invoices.find(params[:id])
  end
end
