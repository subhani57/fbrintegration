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

  describe '.excluding_sandbox_tests' do
    it 'includes production invoices with blank test_data' do
      production = invoice
      sandbox = taxpayer.invoices.create!(
        invoice_date: Date.current,
        invoice_type: 'Sale Invoice',
        buyer_name: 'Buyer',
        buyer_ntn: '7654321-0',
        buyer_province: 'Punjab',
        buyer_address: 'Karachi',
        buyer_registration_type: 'Registered',
        total_amount: 118,
        tax_amount: 18,
        test_data: { sandbox_test: true }
      )

      ids = described_class.excluding_sandbox_tests.pluck(:id)

      expect(ids).to include(production.id)
      expect(ids).not_to include(sandbox.id)
    end
  end

  describe '.for_user_environment' do
    let(:taxpayer) do
      User.create!(
        email: 'env-filter@example.com',
        password: 'password123',
        role: 'taxpayer',
        approved: true,
        subscription_active_until: 1.month.from_now.to_date,
        preferred_fbr_environment: 'production'
      )
    end

    let!(:production_invoice) { invoice }
    let!(:sandbox_test) do
      taxpayer.invoices.create!(
        invoice_date: Date.current,
        invoice_type: 'Sale Invoice',
        buyer_name: 'Buyer',
        buyer_ntn: '7654321-0',
        buyer_province: 'Punjab',
        buyer_address: 'Karachi',
        buyer_registration_type: 'Registered',
        total_amount: 118,
        tax_amount: 18,
        test_data: { sandbox_test: true }
      )
    end
    let!(:sandbox_submission) do
      taxpayer.invoices.create!(
        invoice_date: Date.current,
        invoice_type: 'Sale Invoice',
        buyer_name: 'Buyer',
        buyer_ntn: '7654321-0',
        buyer_province: 'Punjab',
        buyer_address: 'Karachi',
        buyer_registration_type: 'Registered',
        total_amount: 118,
        tax_amount: 18,
        response_data: { submitted_environment: 'sandbox' }
      )
    end

    before do
      production_invoice.update!(response_data: { submitted_environment: 'production' })
    end

    it 'shows production invoices when user is on production' do
      ids = described_class.for_user_environment(taxpayer).pluck(:id)

      expect(ids).to include(production_invoice.id)
      expect(ids).not_to include(sandbox_test.id, sandbox_submission.id)
    end

    it 'shows sandbox invoices when admin set user to sandbox' do
      taxpayer.update!(allow_sandbox_environment: true, preferred_fbr_environment: 'sandbox')

      ids = described_class.for_user_environment(taxpayer.reload).pluck(:id)

      expect(ids).to include(sandbox_test.id, sandbox_submission.id)
      expect(ids).not_to include(production_invoice.id)
    end
  end
end
