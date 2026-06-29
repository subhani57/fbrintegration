# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoice, type: :model do
  include ActiveJob::TestHelper

  let(:taxpayer) do
    User.create!(
      email: 'submit@example.com',
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

  let(:invoice) do
    taxpayer.invoices.create!(
      invoice_date: Date.current,
      invoice_type: 'Sale Invoice',
      buyer_name: 'Buyer',
      buyer_ntn: '7654321-0',
      buyer_province: 'Punjab',
      buyer_address: 'Karachi',
      buyer_registration_type: 'Registered',
      total_amount: 1180,
      tax_amount: 180
    ).tap do |inv|
      inv.items.create!(description: 'Item', quantity: 1, unit_price: 1000, tax_rate: 18, total_value: 1000, sales_tax: 180)
    end
  end

  it 'enqueues FBR submission when submit_to_fbr! is called' do
    clear_enqueued_jobs

    expect do
      invoice.submit_to_fbr!
    end.to have_enqueued_job(FbrSubmissionJob).with(invoice.id)

    expect(invoice.reload).to be_submitting
  end

  it 'enqueues validation when validate_invoice! is called' do
    clear_enqueued_jobs

    expect do
      invoice.validate_invoice!
    end.to have_enqueued_job(FbrValidationJob).with(invoice.id)

    expect(invoice.reload).to be_validating
  end
end
