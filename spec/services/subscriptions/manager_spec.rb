# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscriptions::Manager do
  let(:admin) { User.create!(email: 'admin@example.com', password: 'password123', role: 'admin', approved: true) }
  let(:taxpayer) { User.create!(email: 't@example.com', password: 'password123', role: 'taxpayer', approved: true) }

  describe '.extend!' do
    it 'extends from today when expired' do
      described_class.extend!(user: taxpayer, recorded_by: admin, months: 1)
      expect(taxpayer.reload.subscription_active_until).to eq(Date.current + 1.month)
    end

    it 'stacks extension from current expiry when still active' do
      taxpayer.update!(subscription_active_until: Date.current + 10.days)
      described_class.extend!(user: taxpayer, recorded_by: admin, months: 1)
      expect(taxpayer.reload.subscription_active_until).to eq(Date.current + 10.days + 1.month)
    end
  end

  describe '.grant_trial!' do
    it 'grants trial only once' do
      described_class.grant_trial!(taxpayer, recorded_by: admin)
      expect(taxpayer.reload.subscription_active?).to be true
      expect { described_class.grant_trial!(taxpayer, recorded_by: admin) }.not_to change(SubscriptionPayment, :count)
    end

    it 'does not treat unpaid receipts as prior payments' do
      Subscriptions::ReceiptBuilder.call(
        user: taxpayer,
        recorded_by: admin,
        months: 1,
        monthly_fee: 1000
      )

      expect(taxpayer.reload.subscription_active?).to be false
      described_class.grant_trial!(taxpayer, recorded_by: admin)
      expect(taxpayer.reload.subscription_active?).to be true
    end
  end

  describe '.mark_receipt_paid!' do
    it 'activates the subscription when a pending receipt is marked paid' do
      payment = Subscriptions::ReceiptBuilder.call(
        user: taxpayer,
        recorded_by: admin,
        months: 2,
        monthly_fee: 1000
      )[:payment]

      expect(payment.pending?).to be true
      expect(taxpayer.reload.subscription_active_until).to be_nil

      described_class.mark_receipt_paid!(payment, recorded_by: admin)

      payment.reload
      expect(payment.paid?).to be true
      expect(payment.paid_at).to be_present
      expect(taxpayer.reload.subscription_active_until).to eq(Date.current + 2.months)
    end
  end

  describe '.reduce!' do
    it 'reduces the subscription expiry date' do
      taxpayer.update!(subscription_active_until: Date.current + 6.months)

      described_class.reduce!(user: taxpayer, recorded_by: admin, months: 2)

      expect(taxpayer.reload.subscription_active_until).to eq(Date.current + 4.months)
      expect(taxpayer.subscription_payments.last.notes).to include('Reduced by 2 month(s)')
    end

    it 'rejects reducing to the same or a later date' do
      taxpayer.update!(subscription_active_until: Date.current + 1.month)

      expect do
        described_class.reduce!(user: taxpayer, recorded_by: admin, active_until: Date.current + 2.months)
      end.to raise_error(Subscriptions::Manager::Error, /before the current expiry/)
    end
  end

  describe '.destroy_payment!' do
    it 'deletes the payment and recalculates subscription access from remaining paid records' do
      older = Subscriptions::Manager.record_payment!(
        user: taxpayer,
        active_until: Date.current + 1.month,
        recorded_by: admin
      )
      newer = Subscriptions::Manager.record_payment!(
        user: taxpayer,
        active_until: Date.current + 4.months,
        recorded_by: admin
      )

      described_class.destroy_payment!(newer, recorded_by: admin)

      expect(SubscriptionPayment.exists?(newer.id)).to be false
      expect(taxpayer.reload.subscription_active_until).to eq(older.active_until)
    end

    it 'clears subscription access when the last paid payment is deleted' do
      payment = Subscriptions::Manager.record_payment!(
        user: taxpayer,
        active_until: Date.current + 1.month,
        recorded_by: admin
      )

      described_class.destroy_payment!(payment, recorded_by: admin)

      expect(taxpayer.reload.subscription_active_until).to be_nil
    end
  end

  describe '.grant_free_forever!' do
    it 'marks the taxpayer as free forever and records a zero payment' do
      described_class.grant_free_forever!(taxpayer, recorded_by: admin)

      taxpayer.reload
      expect(taxpayer.subscription_free_forever?).to be true
      expect(taxpayer.subscription_active?).to be true
      expect(taxpayer.subscription_status).to eq(:free_forever)
      expect(taxpayer.subscription_payments.last.notes).to include('Forever free')
    end

    it 'is idempotent' do
      described_class.grant_free_forever!(taxpayer, recorded_by: admin)

      expect do
        described_class.grant_free_forever!(taxpayer, recorded_by: admin)
      end.not_to change(SubscriptionPayment, :count)
    end
  end
end
