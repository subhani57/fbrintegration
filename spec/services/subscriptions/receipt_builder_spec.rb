# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::ReceiptBuilder do
  let(:admin) { User.create!(email: 'receipt-admin@example.com', password: 'password123', role: 'admin', approved: true) }
  let(:taxpayer) { User.create!(email: 'receipt-user@example.com', password: 'password123', role: 'taxpayer', approved: true) }

  describe '.call' do
    it 'creates a payment with subscription and extra line items' do
      result = described_class.call(
        user: taxpayer,
        recorded_by: admin,
        months: 3,
        monthly_fee: 1000,
        extra_lines: [
          { description: 'Onboarding support', amount: 500 }
        ],
        notes: 'Bank transfer received'
      )

      payment = result[:payment]
      expect(payment.amount.to_f).to eq(3500.0)
      expect(payment.months).to eq(3)
      expect(payment.monthly_fee).to eq(1000)
      expect(payment.pending?).to be true
      expect(payment.line_items.count).to eq(2)
      expect(payment.line_items.pluck(:description)).to include('Subscription (3 months)', 'Onboarding support')
      expect(taxpayer.reload.subscription_active_until).to be_nil
    end

    it 'requires a description for additional charges' do
      expect do
        described_class.call(
          user: taxpayer,
          recorded_by: admin,
          months: 1,
          monthly_fee: 1000,
          extra_lines: [{ description: '', amount: 250 }]
        )
      end.to raise_error(described_class::Error, /description/)
    end

    it 'parses Rails-style extra_lines hash params' do
      result = described_class.call(
        user: taxpayer,
        recorded_by: admin,
        months: 2,
        monthly_fee: 1000,
        extra_lines: {
          '0' => { 'description' => 'Setup fee', 'amount' => '500' },
          '1' => { 'description' => 'Training', 'amount' => '300' }
        },
        notes: 'Paid via bank'
      )

      payment = result[:payment]
      expect(payment.amount.to_f).to eq(2800.0)
      expect(payment.line_items.pluck(:description)).to contain_exactly(
        'Subscription (2 months)', 'Setup fee', 'Training'
      )
    end

    it 'parses parallel description and amount arrays' do
      result = described_class.call(
        user: taxpayer,
        recorded_by: admin,
        months: 1,
        monthly_fee: 1000,
        extra_lines: [
          { description: 'Setup fee', amount: '500' },
          { description: 'Training', amount: '300' }
        ]
      )

      payment = result[:payment]
      expect(payment.amount.to_f).to eq(1800.0)
      expect(payment.line_items.pluck(:description)).to include('Setup fee', 'Training')
    end
  end
end

RSpec.describe Subscriptions::ReceiptGenerator do
  let(:admin) { User.create!(email: 'gen-admin@example.com', password: 'password123', role: 'admin', approved: true) }
  let(:taxpayer) do
    User.create!(
      email: 'gen-user@example.com',
      password: 'password123',
      role: 'taxpayer',
      approved: true,
      business_name: 'Acme Traders',
      ntn_cnic: '1234567',
      address: 'Lahore, Punjab'
    )
  end

  it 'includes line item breakdown in the receipt text' do
    payment = Subscriptions::ReceiptBuilder.call(
      user: taxpayer,
      recorded_by: admin,
      months: 2,
      monthly_fee: 1000,
      extra_lines: [{ description: 'Training', amount: 300 }]
    )[:payment]

    text = described_class.new(payment).to_text
    expect(text).to include('Subscription (2 months)')
    expect(text).to include('Training')
    expect(text).to include('Total: Rs. 2300.00')
  end

  it 'generates a PDF receipt' do
    payment = Subscriptions::ReceiptBuilder.call(
      user: taxpayer,
      recorded_by: admin,
      months: 1,
      monthly_fee: 1000,
      extra_lines: { '0' => { 'description' => 'Custom integration', 'amount' => '1500' } },
      notes: 'Bank transfer'
    )[:payment]

    generator = described_class.new(payment)
    pdf = generator.to_pdf
    text = generator.to_text

    expect(generator.filename).to end_with('.pdf')
    expect(generator.content_type).to eq('application/pdf')
    expect(pdf).to start_with('%PDF')
    expect(pdf.bytesize).to be > 1000
    expect(text).to include('Custom integration')
    expect(text).to include('Bank transfer')
  end
end
