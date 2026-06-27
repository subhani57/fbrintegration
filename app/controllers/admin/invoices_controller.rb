module Admin
  class InvoicesController < BaseController
    before_action :set_invoice, only: [:show, :download_pdf]

    def index
      @invoices = Invoice.includes(:user, :items)
        .order(created_at: :desc)
        .page(params[:page])
        .per(30)

      if params[:status].present?
        @invoices = @invoices.where(status: params[:status])
      end

      if params[:user_id].present?
        @invoices = @invoices.where(user_id: params[:user_id])
      end

      if params[:q].present?
        q = "%#{params[:q]}%"
        @invoices = @invoices.where(
          'invoice_number ILIKE :q OR buyer_name ILIKE :q OR buyer_ntn ILIKE :q',
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
      @invoice = Invoice.find(params[:id])
    end
  end
end
