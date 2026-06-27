module Admin
  class InvoicesController < BaseController
    before_action :set_invoice, only: [:show, :download_pdf]

    def index
      @invoices = Invoice.includes(:user)
        .order(invoice_date: :desc, created_at: :desc)
        .page(params[:page])
        .per(30)

      if params[:status].present?
        @invoices = @invoices.where(status: params[:status])
      end

      if params[:user_id].present?
        @invoices = @invoices.where(user_id: params[:user_id])
      end

      if params[:q].present?
        q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        @invoices = @invoices.joins(:user).where(
          <<~SQL.squish,
            invoices.invoice_number ILIKE :q
            OR invoices.pdf_invoice_number ILIKE :q
            OR invoices.buyer_name ILIKE :q
            OR invoices.buyer_ntn ILIKE :q
            OR invoices.fbr_invoice_id ILIKE :q
            OR users.email ILIKE :q
            OR users.business_name ILIKE :q
          SQL
          q: q
        )
      end

      @users_for_filter = User.taxpayers.order(:email)
      @stats = {
        total: Invoice.count,
        submitted: Invoice.where(fbr_status: 'submitted').count,
        failed: Invoice.where(status: 'failed').count,
        draft: Invoice.where(status: 'draft').count
      }
    end

    def show
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
      @invoice = Invoice.includes(:items, :user).find(params[:id])
    end
  end
end
