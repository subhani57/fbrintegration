# frozen_string_literal: true

require 'csv'

module Invoices
  class CsvImporter
    Result = Struct.new(:success, :invoice, :errors, keyword_init: true)

    HEADERS = %w[
      invoice_date invoice_no buyer_name buyer_ntn buyer_province buyer_address
      description hs_code quantity uom unit_price
    ].freeze

    def initialize(user, file)
      @user = user
      @file = file
    end

    def call
      results = []
      each_row.with_index(1) do |row, line|
        results << import_row(row, line)
      end
      results
    rescue CSV::MalformedCSVError => e
      [Result.new(success: false, invoice: nil, errors: ["Invalid CSV: #{e.message}"])]
    end

    private

    def each_row(&block)
      content = File.read(@file.path).delete_prefix("\uFEFF")
      CSV.parse(content, headers: true).each(&block)
    end

    def import_row(row, line)
      invoice = @user.invoices.new(
        invoice_date: parse_date(row['invoice_date']) || Date.current,
        invoice_type: 'Sale Invoice',
        pdf_invoice_number: CsvTextField.normalize_invoice_no(row['invoice_no']),
        buyer_name: CsvTextField.normalize(row['buyer_name']),
        buyer_ntn: CsvTextField.normalize_ntn(row['buyer_ntn']),
        buyer_province: CsvTextField.normalize(row['buyer_province']).presence || Company::DEFAULT_PROVINCE,
        buyer_address: CsvTextField.normalize(row['buyer_address']),
        buyer_registration_type: Invoice::DEFAULT_BUYER_REGISTRATION_TYPE
      )
      invoice.items.build(
        description: CsvTextField.normalize(row['description']),
        hs_code: CsvTextField.normalize_hs_code(row['hs_code']),
        quantity: parse_decimal(row['quantity']),
        uom: CsvTextField.normalize(row['uom']).presence || 'Numbers, pieces, units',
        unit_price: parse_decimal(row['unit_price']),
        tax_rate: InvoiceItem::DEFAULT_TAX_RATE
      )

      if invoice.save
        Result.new(success: true, invoice: invoice, errors: [])
      else
        Result.new(success: false, invoice: nil, errors: ["Row #{line}: #{invoice.errors.full_messages.join(', ')}"])
      end
    end

    def parse_date(value)
      raw = CsvTextField.normalize(value)
      return nil if raw.blank?

      Date.parse(raw)
    rescue ArgumentError
      nil
    end

    def parse_decimal(value)
      raw = CsvTextField.normalize(value)
      return nil if raw.blank?

      raw.delete(',').to_d
    end
  end
end
