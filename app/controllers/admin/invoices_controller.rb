module Admin
  class InvoicesController < BaseController
    include InvoiceExcelExportable
    before_action :set_invoice, only: [:show, :download_pdf]

    def index
      reportable = Invoice.excluding_sandbox_tests
      scope = invoice_list_scope(reportable)

      respond_to do |format|
        format.html do
          assign_export_dates
          @invoices = scope.with_user.page(params[:page]).per(30)
          @users_for_filter = User.taxpayers.order(:email)
          @stats = admin_invoice_stats(reportable)
        end
        format.xlsx do
          dates = export_date_range_or_redirect(admin_invoices_path)
          return unless dates

          start_date, end_date = dates
          send_data Invoices::ExcelExporter.new(invoice_list_scope(reportable).with_user, admin: true).to_stream,
                    filename: invoice_export_filename('admin-invoices', start_date, end_date),
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    disposition: 'attachment'
        end
      end
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
      @invoice = Invoice.with_detail_associations.find(params[:id])
    end

    def invoice_list_scope(base_scope)
      Invoices::ListScope.call(scope: base_scope, params: params, admin: true)
    end

    def admin_invoice_stats(reportable)
      {
        total: reportable.count,
        submitted: reportable.where(fbr_status: 'submitted').count,
        failed: reportable.where(status: 'failed').count,
        draft: reportable.where(status: 'draft').count
      }
    end
  end
end
