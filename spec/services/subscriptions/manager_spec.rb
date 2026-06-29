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
  end
end
