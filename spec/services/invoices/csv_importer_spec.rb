# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::CsvImporter do
  let(:taxpayer) do
    User.create!(
      email: 'import@example.com',
      password: 'password123',
      role: 'taxpayer',
      approved: true,
      subscription_active_until: 1.month.from_now.to_date
    )
  end

  def import_csv(content)
    file = Tempfile.new(['invoices', '.csv'])
    file.write(content)
    file.rewind
    described_class.new(taxpayer, file).call
  ensure
    file&.close!
  end

  it 'normalizes NTN and HS code from Excel-stripped values' do
    csv = <<~CSV
      invoice_date,invoice_no,buyer_name,buyer_ntn,buyer_province,buyer_address,description,hs_code,quantity,uom,unit_price
      2026-06-27,1,SURAJ COTTON MILLS LIMITED,698469,Punjab,Lahore,Paper,4819.1,1,Numbers pieces units,1
    CSV

    results = import_csv(csv)
    invoice = results.first.invoice
    item = invoice.items.first

    expect(invoice.buyer_ntn).to eq('0698469')
    expect(item.hs_code).to eq('4819.1000')
  end

  it 'calculates line total and sales tax at 18% with the new CSV format' do
    csv = <<~CSV
      invoice_date,invoice_no,buyer_name,buyer_ntn,buyer_province,buyer_address,description,hs_code,quantity,uom,unit_price
      2026-06-27,INV-001,ABC Traders,1234567-8,Punjab,Lahore,Paper,4802.5690,10,Numbers pieces units,2500
    CSV

    results = import_csv(csv)
    expect(results.first.success).to be true

    invoice = results.first.invoice
    item = invoice.items.first
    expect(invoice.pdf_invoice_number).to eq('INV-001')
    expect(item.total_value).to eq(25_000.0)
    expect(item.tax_rate).to eq(18)
    expect(item.sales_tax).to eq(4500.0)
    expect(invoice.tax_amount).to eq(4500.0)
    expect(invoice.total_amount).to eq(29_500.0)
  end

  it 'auto-assigns invoice number when invoice_no is omitted' do
    csv = <<~CSV
      invoice_date,invoice_no,buyer_name,buyer_ntn,buyer_province,buyer_address,description,hs_code,quantity,uom,unit_price
      2026-06-27,,ABC Traders,1234567-8,Punjab,Lahore,Paper,4802.5690,2,Numbers pieces units,1000
    CSV

    results = import_csv(csv)
    invoice = results.first.invoice

    expect(invoice.pdf_invoice_number).to be_present
    expect(invoice.pdf_invoice_number).to match(/\A\d{8}-\d{4}\z/)
  end

  it 'groups multiple rows with the same invoice_no into one invoice' do
    csv = <<~CSV
      invoice_date,invoice_no,buyer_name,buyer_ntn,buyer_province,buyer_address,description,hs_code,quantity,uom,unit_price
      2026-06-24,92,ALI ENTERPRISES,3372090-8,Punjab,"Main Barki Road, Bahowala, Lahore",21x17x13Box,4819.1000,637,Numbers pieces units,390
      2026-06-24,92,ALI ENTERPRISES,3372090-8,Punjab,"Main Barki Road, Bahowala, Lahore",18.5x12x12Box,4819.1000,650,Numbers pieces units,253
    CSV

    results = import_csv(csv)
    expect(results.size).to eq(1)
    expect(results.first.success).to be true

    invoice = results.first.invoice
    expect(invoice.pdf_invoice_number).to eq('92')
    expect(invoice.items.count).to eq(2)
    expect(invoice.items.map { |i| [i.quantity.to_f, i.unit_price.to_f] }).to eq([[637.0, 390.0], [650.0, 253.0]])
    expect(invoice.tax_amount).to eq(74_318.4)
    expect(invoice.total_amount).to eq(487_198.4)
  end
end
