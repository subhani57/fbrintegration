# frozen_string_literal: true

require 'csv'

module Compliance
  class Exporter
    def initialize(user, start_date:, end_date:)
      @user = user
      @start_date = start_date
      @end_date = end_date
    end

    def to_csv
      CSV.generate do |csv|
        csv << ['Invoice #', 'Date', 'Type', 'Buyer', 'NTN', 'FBR #', 'Status', 'Total', 'Tax', 'Submitted At']
        scope.find_each do |inv|
          csv << [
            inv.pdf_display_number, inv.invoice_date, inv.invoice_type, inv.buyer_name, inv.buyer_ntn,
            inv.fbr_invoice_id, inv.status, inv.total_amount, inv.tax_amount, inv.submitted_at
          ]
        end
      end
    end

    private

    def scope
      @user.invoices.where(invoice_date: @start_date..@end_date).order(:invoice_date)
    end
  end
end
