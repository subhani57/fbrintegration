# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fbr::SandboxTestInvoicesService do
  describe 'SCENARIO_IDS' do
    it 'includes retailer end-consumer scenarios per FBR sandbox spec' do
      expect(described_class::SCENARIO_IDS).to include('SN026', 'SN027', 'SN028')
    end
  end

  describe '#scenario_specs (via send)' do
    let(:user) do
      User.create!(
        email: 'sandbox@example.com',
        password: 'password123',
        role: 'taxpayer',
        approved: true,
        subscription_active_until: 1.month.from_now.to_date,
        ntn_cnic: '1234567-8',
        business_name: 'Test Retailer',
        address: 'Lahore',
        seller_province: 'Punjab'
      )
    end

    let(:specs) { described_class.new(user).send(:scenario_specs).index_by { |s| s[:scenario_id] } }

    it 'defines SN026 as standard rate to unregistered end consumer' do
      spec = specs['SN026']
      expect(spec[:buyer_registration_type]).to eq('Unregistered')
      expect(spec[:item][:saleType]).to eq('Goods at standard rate (default)')
      expect(spec[:item][:rate]).to eq('18%')
    end

    it 'defines SN027 as 3rd schedule with MRP-based tax (positive valueSalesExcludingST)' do
      item = specs['SN027'][:item]
      expect(item[:saleType]).to eq('3rd Schedule Goods')
      expect(item[:valueSalesExcludingST]).to eq(100.0)
      expect(item[:fixedNotifiedValueOrRetailPrice]).to eq(100.0)
      expect(item[:salesTaxApplicable]).to eq(18.0)
    end

    it 'defines SN028 as reduced rate with Eighth Schedule per FBR sample' do
      item = specs['SN028'][:item]
      expect(item[:saleType]).to eq('Goods at Reduced Rate')
      expect(item[:rate]).to eq('1%')
      expect(item[:sroScheduleNo]).to eq('EIGHTH SCHEDULE Table 1')
      expect(item[:sroItemSerialNo]).to eq('70')
      expect(item[:valueSalesExcludingST]).to eq(99.01)
      expect(item[:fixedNotifiedValueOrRetailPrice]).to eq(100.0)
      expect(item[:salesTaxApplicable]).to eq(0.99)
    end
  end
end
