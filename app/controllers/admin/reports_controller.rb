module Admin
  class ReportsController < BaseController
    def index
      @start_date = parse_date(params[:start_date]) || Date.today.beginning_of_month
      @end_date = parse_date(params[:end_date]) || Date.today.end_of_month

      @invoices = Invoice.includes(:user)
        .where(invoice_date: @start_date..@end_date)
        .order(invoice_date: :desc)

      @summary = {
        total_invoices: @invoices.count,
        total_amount: @invoices.sum(:total_amount),
        total_tax: @invoices.sum(:tax_amount),
        submitted: @invoices.where(fbr_status: 'submitted').count,
        failed: @invoices.where(status: 'failed').count
      }

      respond_to do |format|
        format.html
        format.csv do
          csv = CSV.generate(headers: true) do |csv_builder|
            csv_builder << %w[id invoice_number invoice_date total_amount tax_amount user_email status fbr_status]
            @invoices.find_each do |inv|
              csv_builder << [
                inv.id, inv.invoice_number, inv.invoice_date,
                inv.total_amount, inv.tax_amount, inv.user&.email,
                inv.status, inv.fbr_status
              ]
            end
          end
          send_data csv, filename: "admin-invoices-#{@start_date}-#{@end_date}.csv"
        end
      end
    end

    private

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
