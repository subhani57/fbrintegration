# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::AmountSummary do
  let(:user) do
    User.create!(
      email: 'amounts@example.com',
      password: 'password123',
      role: 'taxpayer',
      approved: true,
      subscription_active_until: 1.month.from_now.to_date
    )
  end

  def build_invoice(status:, total_amount:, tax_amount:)
    user.invoices.create!(
      invoice_date: Date.current,
      invoice_type: 'Sale Invoice',
      status: status,
      buyer_name: 'Buyer',
      buyer_ntn: '7654321-0',
      buyer_province: 'Punjab',
      buyer_address: 'Lahore',
      buyer_registration_type: 'Registered',
      total_amount: total_amount,
      tax_amount: tax_amount
    )
  end

  it 'splits approved and failed/cancelled totals' do
    build_invoice(status: 'approved', total_amount: 118, tax_amount: 18)
    build_invoice(status: 'submitted', total_amount: 236, tax_amount: 36)
    build_invoice(status: 'failed', total_amount: 50, tax_amount: 5)
    build_invoice(status: 'cancelled', total_amount: 30, tax_amount: 3)
    build_invoice(status: 'draft', total_amount: 10, tax_amount: 1)

    result = described_class.for(user.invoices)

    expect(result[:approved][:count]).to eq(2)
    expect(result[:approved][:total_amount]).to eq(354.0)
    expect(result[:approved][:tax_amount]).to eq(54.0)
    expect(result[:approved][:net_amount]).to eq(300.0)

    expect(result[:failed_cancelled][:count]).to eq(2)
    expect(result[:failed_cancelled][:total_amount]).to eq(80.0)
    expect(result[:failed_cancelled][:tax_amount]).to eq(8.0)
  end
end
