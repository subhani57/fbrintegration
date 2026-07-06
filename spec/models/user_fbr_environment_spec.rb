# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'preferred FBR environment' do
    let(:taxpayer) do
      described_class.create!(
        email: 'env-taxpayer@example.com',
        password: 'password123',
        role: 'taxpayer',
        approved: true,
        subscription_active_until: 1.month.from_now.to_date,
        preferred_fbr_environment: 'production'
      )
    end

    it 'defaults missing preference to production' do
      taxpayer.update_column(:preferred_fbr_environment, '')
      taxpayer.reload

      expect(taxpayer.default_fbr_environment).to eq('production')
    end

    it 'prevents taxpayers from enabling sandbox themselves' do
      taxpayer.preferred_fbr_environment = 'sandbox'

      expect(taxpayer).not_to be_valid
      expect(taxpayer.errors[:preferred_fbr_environment]).to include('Sandbox can only be enabled by an administrator.')
    end

    it 'allows administrators to enable sandbox for a taxpayer' do
      taxpayer.allow_sandbox_environment = true
      taxpayer.preferred_fbr_environment = 'sandbox'

      expect(taxpayer).to be_valid
    end
  end
end
