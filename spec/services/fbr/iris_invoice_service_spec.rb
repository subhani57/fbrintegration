# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fbr::IrisInvoiceService do
  subject(:service) { described_class.new(user) }

  let(:user) { User.create!(email: 'iris@example.com', password: 'password123', role: 'taxpayer', approved: true, ntn_cnic: '1234567') }

  describe '#detect_iris_status' do
    it 'detects cancelled status in response data' do
      status = service.send(:detect_iris_status, { 'status' => 'Cancelled' })
      expect(status).to eq(:cancelled)
    end

    it 'detects cancellation from error message' do
      status = service.send(:detect_iris_status, nil, error_message: 'Invoice has been cancelled')
      expect(status).to eq(:cancelled)
    end

    it 'returns active for valid response' do
      status = service.send(:detect_iris_status, { 'status' => 'Valid' })
      expect(status).to eq(:active)
    end
  end
end
