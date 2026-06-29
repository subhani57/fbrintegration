# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::CsvTextField do
  describe '.normalize_ntn' do
    it 'restores a leading zero stripped by Excel for 6-digit NTNs' do
      expect(described_class.normalize_ntn('698469')).to eq('0698469')
    end

    it 'parses Excel text formula cells' do
      expect(described_class.normalize_ntn('="0698469"')).to eq('0698469')
    end

    it 'preserves NTN with check digit' do
      expect(described_class.normalize_ntn('1234567-8')).to eq('1234567-8')
    end
  end

  describe '.normalize_hs_code' do
    it 'pads decimal places stripped by Excel' do
      expect(described_class.normalize_hs_code('4819.1')).to eq('4819.1000')
    end

    it 'keeps fully specified HS codes' do
      expect(described_class.normalize_hs_code('4802.5690')).to eq('4802.5690')
    end

    it 'parses Excel text formula cells' do
      expect(described_class.normalize_hs_code('="4802.5690"')).to eq('4802.5690')
    end
  end
end
