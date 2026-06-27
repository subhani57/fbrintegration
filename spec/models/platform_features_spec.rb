# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fbr::EnvironmentGuard do
  let(:user) { User.new(role: 'taxpayer', ntn_cnic: '1234567', business_name: 'Test Co', address: 'Addr', preferred_fbr_environment: 'sandbox') }

  describe '.submission_blocked_reason' do
    it 'blocks when token missing' do
      expect(described_class.submission_blocked_reason(user)).to be_present
    end
  end
end

RSpec.describe InvoicePolicy do
  let(:taxpayer) { User.create!(email: 't@example.com', password: 'password123', role: 'taxpayer', approved: true) }
  let(:other) { User.create!(email: 'o@example.com', password: 'password123', role: 'taxpayer', approved: true) }
  let(:invoice) { taxpayer.invoices.create!(invoice_date: Date.today, invoice_type: 'Sale Invoice') }

  it 'allows owner to update draft' do
    expect(described_class.new(taxpayer, invoice).update?).to be true
  end

  it 'denies other user update' do
    expect(described_class.new(other, invoice).update?).to be false
  end

  it 'allows save_template for owner' do
    expect(described_class.new(taxpayer, invoice).save_template?).to be true
  end
end

RSpec.describe Reports::TaxSummary do
  it 'builds csv' do
    csv = described_class.to_csv(period_label: 'Jan', invoice_count: 1, total_sales: 100, total_tax: 18, daily: { Date.today => 100 })
    expect(csv).to include('Output tax')
  end
end
