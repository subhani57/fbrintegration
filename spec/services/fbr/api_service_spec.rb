# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fbr::ApiService do
  let(:user) do
    User.create!(
      email: 'api-service@example.com',
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

  let(:service) { described_class.new(user, :sandbox) }

  def build_item_payload(sale_type:, unit_price: 100, quantity: 1, tax_rate: 18, sales_tax: 18)
    item = InvoiceItem.new(
      description: 'Test item',
      quantity: quantity,
      unit_price: unit_price,
      total_value: unit_price * quantity,
      tax_rate: tax_rate,
      sales_tax: sales_tax,
      hs_code: '0101.2100',
      uom: 'Numbers, pieces, units',
      sale_type: sale_type
    )

    service.send(:build_items_payload, [item]).first
  end

  describe '#build_items_payload' do
    it 'sets MRP for 3rd schedule goods' do
      payload = build_item_payload(sale_type: '3rd Schedule Goods')

      expect(payload[:fixedNotifiedValueOrRetailPrice]).to eq(100.0)
      expect(payload[:valueSalesExcludingST]).to eq(100.0)
    end

    it 'sets retail price for reduced rate goods' do
      payload = build_item_payload(
        sale_type: 'Goods at Reduced Rate',
        unit_price: 99.01,
        sales_tax: 0.99,
        tax_rate: 1
      )

      expect(payload[:fixedNotifiedValueOrRetailPrice]).to eq(100.0)
    end

    it 'keeps zero retail price for standard goods' do
      payload = build_item_payload(sale_type: 'Goods at standard rate (default)')

      expect(payload[:fixedNotifiedValueOrRetailPrice]).to eq(0.0)
    end
  end
end
