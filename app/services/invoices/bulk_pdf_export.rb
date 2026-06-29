# frozen_string_literal: true

module Invoices
  class BulkPdfExport
    def initialize(invoices)
      @invoices = invoices
    end

    def to_zip
      require 'zip'
      buffer = Zip::OutputStream.write_buffer do |zip|
        @invoices.each do |invoice|
          pdf = invoice.generate_pdf
          safe_name = invoice.pdf_display_number.to_s.gsub(/[^\w.-]+/, '_')
          zip.put_next_entry("invoice-#{safe_name}.pdf")
          zip.write pdf
        end
      end
      buffer.string
    end
  end
end
