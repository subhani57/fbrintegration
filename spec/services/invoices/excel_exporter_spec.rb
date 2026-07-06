# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::ExcelExporter do
  let(:taxpayer) do
    User.create!(
      email: 'excel-export@example.com',
      password: 'password123',
      role: 'taxpayer',
      approved: true,
      subscription_active_until: 1.month.from_now.to_date,
      ntn_cnic: '1234567-8',
      business_name: 'Test Co',
      address: 'Lahore',
      seller_province: 'Punjab'
    )
  end

  let!(:invoice) do
    taxpayer.invoices.create!(
      invoice_date: Date.current,
      invoice_type: 'Sale Invoice',
      buyer_name: 'Acme Ltd',
      buyer_ntn: '7654321-0',
      buyer_province: 'Punjab',
      buyer_address: 'Karachi',
      buyer_registration_type: 'Registered',
      total_amount: 1000,
      tax_amount: 150
    )
  end

  it 'builds a taxpayer export file' do
    data = described_class.new(Invoice.where(id: invoice.id)).to_stream

    expect(data.bytesize).to be > 100
    expect(data[0, 2]).to eq('PK')
  end

  it 'builds an admin export file' do
    data = described_class.new(Invoice.with_user.where(id: invoice.id), admin: true).to_stream

    expect(data.bytesize).to be > 100
  end
end

RSpec.describe Invoices::ListScope do
  let(:taxpayer) do
    User.create!(
      email: 'list-scope@example.com',
      password: 'password123',
      role: 'taxpayer',
      approved: true,
      subscription_active_until: 1.month.from_now.to_date,
      ntn_cnic: '1234567-9',
      business_name: 'Scope Co',
      address: 'Lahore',
      seller_province: 'Punjab'
    )
  end

  let!(:invoice) do
    taxpayer.invoices.create!(
      invoice_date: Date.current,
      invoice_type: 'Sale Invoice',
      buyer_name: 'Unique Buyer Co',
      buyer_ntn: '7654321-1',
      buyer_province: 'Punjab',
      buyer_address: 'Karachi',
      buyer_registration_type: 'Registered',
      status: 'draft',
      total_amount: 1000,
      tax_amount: 150
    )
  end

  it 'filters by status and search query' do
    scope = described_class.call(scope: Invoice.all, params: { status: 'draft', q: 'Unique Buyer' })

    expect(scope).to contain_exactly(invoice)
  end

  it 'filters by invoice date range' do
    old_invoice = taxpayer.invoices.create!(
      invoice_date: 2.months.ago.to_date,
      invoice_type: 'Sale Invoice',
      buyer_name: 'Old Buyer',
      buyer_ntn: '7654321-2',
      buyer_province: 'Punjab',
      buyer_address: 'Karachi',
      buyer_registration_type: 'Registered',
      total_amount: 500,
      tax_amount: 50
    )

    scope = described_class.call(
      scope: Invoice.all,
      params: { start_date: Date.current.beginning_of_month, end_date: Date.current }
    )

    expect(scope).to contain_exactly(invoice)
    expect(scope).not_to include(old_invoice)
  end
end
