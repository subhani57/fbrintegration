# frozen_string_literal: true

require 'caxlsx'

module Invoices
  class ExcelExporter
    TAXPAYER_HEADERS = [
      'Date', 'Invoice #', 'Buyer', 'Buyer NTN', 'Amount (PKR)', 'Tax (PKR)',
      'Grand Total (PKR)', 'Status', 'FBR Invoice #'
    ].freeze

    ADMIN_HEADERS = ['Taxpayer Email', 'Taxpayer Business', *TAXPAYER_HEADERS].freeze

    def initialize(invoices, admin: false)
      @invoices = invoices
      @admin = admin
    end

    def to_stream
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Invoices') do |sheet|
        sheet.add_row(@admin ? ADMIN_HEADERS : TAXPAYER_HEADERS)
        @invoices.find_each { |invoice| sheet.add_row(row_for(invoice)) }
      end
      package.to_stream.read
    end

    private

    def row_for(invoice)
      net_amount = invoice.total_amount.to_d - invoice.tax_amount.to_d

      base = [
        invoice.invoice_date,
        invoice.pdf_display_number,
        invoice.buyer_name,
        invoice.buyer_ntn,
        decimal(net_amount),
        decimal(invoice.tax_amount),
        decimal(invoice.total_amount),
        invoice.status.to_s.humanize,
        invoice.fbr_invoice_id
      ]

      return base unless @admin

      [invoice.user&.email, invoice.user&.business_name, *base]
    end

    def decimal(value)
      return nil if value.nil?

      value.to_d
    end
  end
end
