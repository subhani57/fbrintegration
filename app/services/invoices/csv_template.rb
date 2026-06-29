# frozen_string_literal: true

require 'csv'

module Invoices
  class CsvTemplate
    ROWS = [
      {
        invoice_date: '2026-06-27',
        invoice_no: '1',
        buyer_name: 'SURAJ COTTON MILLS LIMITED',
        buyer_ntn: '0698469',
        buyer_province: 'Punjab',
        buyer_address: 'Tricon Corporation 8th Floor 73-E Main Gulberg',
        description: 'Office supplies - paper reams',
        hs_code: '4819.1000',
        quantity: '1',
        uom: 'Numbers, pieces, units',
        unit_price: '1'
      },
      {
        invoice_date: '2026-06-27',
        invoice_no: '2',
        buyer_name: 'SURAJ COTTON MILLS LIMITED',
        buyer_ntn: '0698469',
        buyer_province: 'Punjab',
        buyer_address: 'Tricon Corporation 8th Floor 73-E Main Gulberg',
        description: 'Laptop computers',
        hs_code: '4819.1000',
        quantity: '1',
        uom: 'Numbers, pieces, units',
        unit_price: '1'
      },
      {
        invoice_date: '2026-06-28',
        invoice_no: '3',
        buyer_name: 'SURAJ COTTON MILLS LIMITED',
        buyer_ntn: '0698469',
        buyer_province: 'Punjab',
        buyer_address: 'Tricon Corporation 8th Floor 73-E Main Gulberg',
        description: 'Plastic packaging material',
        hs_code: '4819.1000',
        quantity: '1',
        uom: 'Numbers, pieces, units',
        unit_price: '1'
      }
    ].freeze

    TEXT_COLUMNS = %i[buyer_ntn hs_code invoice_no].freeze

    def self.to_csv
      csv = CSV.generate do |out|
        out << CsvImporter::HEADERS
        ROWS.each do |row|
          out << CsvImporter::HEADERS.map do |header|
            value = row[header.to_sym]
            TEXT_COLUMNS.include?(header.to_sym) ? CsvTextField.excel_cell(value) : value
          end
        end
      end
      "\uFEFF#{csv}"
    end
  end
end
