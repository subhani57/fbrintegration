# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Clone do
  let(:admin) { User.create!(email: 'clone-admin@example.com', password: 'password123', role: 'admin', approved: true) }
  let!(:source) do
    User.new(
      email: 'source@example.com',
      password: 'password123',
      role: 'taxpayer',
      approved: true,
      subscription_active_until: 1.month.from_now.to_date,
      business_name: 'Source Co',
      ntn_cnic: '1234567',
      address: 'Lahore',
      seller_province: 'Punjab',
      preferred_fbr_environment: 'sandbox'
    ).tap do |user|
      user.allow_sandbox_environment = true
      user.save!
    end
  end

  before do
    company = source.companies.create!(
      name: 'Buyer Ltd',
      ntn: '7654321',
      province: 'Punjab',
      address: 'Karachi',
      registration_type: 'Registered'
    )
    invoice = source.invoices.create!(
      invoice_date: Date.current,
      invoice_type: 'Sale Invoice',
      buyer_name: 'Buyer Ltd',
      buyer_ntn: '7654321',
      buyer_province: 'Punjab',
      buyer_address: 'Karachi',
      buyer_registration_type: 'Registered',
      buyer_company: company,
      total_amount: 118,
      tax_amount: 18
    )
    invoice.items.create!(
      description: 'Widget',
      quantity: 1,
      unit_price: 100,
      tax_rate: 18,
      total_value: 100,
      sales_tax: 18
    )
    source.fbr_configurations.find_or_create_by!(environment: 'sandbox') do |config|
      config.token = 'sandbox-token'
      config.active = true
    end
    source.notifications.create!(title: 'Test', body: 'Hello')
  end

  it 'clones the user and related records' do
    result = described_class.call(
      source_email: source.email,
      target_email: 'target@example.com',
      password: 'cloned-password'
    )

    target = result[:target]
    expect(target.email).to eq('target@example.com')
    expect(target.business_name).to eq('Source Co')
    expect(target.companies.count).to eq(1)
    expect(target.invoices.count).to eq(1)
    expect(target.invoices.first.items.count).to eq(1)
    expect(target.fbr_configurations.count).to eq(1)
    expect(target.notifications.count).to eq(1)
    expect(target.valid_password?('cloned-password')).to be true
  end

  it 'raises when the target already exists without replace flag' do
    User.create!(email: 'target@example.com', password: 'password123', role: 'taxpayer', approved: true)

    expect do
      described_class.call(source_email: source.email, target_email: 'target@example.com')
    end.to raise_error(Users::Clone::Error, /already exists/)
  end
end
