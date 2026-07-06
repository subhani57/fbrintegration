# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fbr::HsCodesCatalog do
  let(:user) do
    instance_double(
      User,
      id: 1,
      default_fbr_environment: 'sandbox'
    )
  end

  let(:catalog) { described_class.for_user(user) }
  let(:reference_service) { instance_double(Fbr::ReferenceService) }

  before do
    Rails.cache.clear
    allow(Fbr::ReferenceService).to receive(:new).and_return(reference_service)
    allow(reference_service).to receive(:items).and_return([])
  end

  describe '#all' do
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original_cache
    end

    it 'falls back to the user token when the system token cannot load HS codes' do
      user_service = instance_double(Fbr::ReferenceService)
      system_service = instance_double(Fbr::ReferenceService)
      alternate_service = instance_double(Fbr::ReferenceService)

      allow(Fbr::ReferenceService).to receive(:new)
        .with(user, prefer_system_token: false, environment: 'sandbox')
        .and_return(user_service)
      allow(Fbr::ReferenceService).to receive(:new)
        .with(user, prefer_system_token: true, environment: 'sandbox')
        .and_return(system_service)
      allow(Fbr::ReferenceService).to receive(:new)
        .with(user, prefer_system_token: true, environment: 'production')
        .and_return(alternate_service)

      allow(system_service).to receive(:items).and_return(nil)
      allow(alternate_service).to receive(:items).and_return(nil)
      allow(user_service).to receive(:items).and_return([
        { 'hS_CODE' => '3910.1000', 'description' => 'Plastics' }
      ])

      expect(catalog.all).to eq([{ code: '3910.1000', description: 'Plastics' }])
      expect(user_service).to have_received(:items)
      expect(system_service).not_to have_received(:items)
    end

    it 'normalizes FBR item codes and caches them' do
      allow(reference_service).to receive(:items).and_return([
        { 'hS_CODE' => '3910.1000', 'description' => 'Plastics' }
      ])

      first = catalog.all
      second = catalog.all

      expect(first).to eq([{ code: '3910.1000', description: 'Plastics' }])
      expect(second).to eq(first)
      expect(reference_service).to have_received(:items).once
    end

    it 'does not cache empty results' do
      allow(reference_service).to receive(:items).and_return([])

      expect(catalog.all).to eq([])
      expect(reference_service).to have_received(:items).exactly(3).times

      catalog.all
      expect(reference_service).to have_received(:items).exactly(6).times
    end

    it 'unwraps hash responses from FBR' do
      allow(reference_service).to receive(:items).and_return(
        'data' => [{ 'HS_CODE' => '3910.2000', 'description' => 'Sheets' }]
      )

      expect(catalog.all).to eq([{ code: '3910.2000', description: 'Sheets' }])
    end
  end

  describe '#search' do
    before do
      allow(reference_service).to receive(:items).and_return([
        { 'hS_CODE' => '3910.1000', 'description' => 'Plastics' },
        { 'hS_CODE' => '0101.2100', 'description' => 'Live horses' }
      ])
    end

    it 'returns matches for partial HS code queries' do
      expect(catalog.search('3910')).to eq([
        { code: '3910.1000', description: 'Plastics' }
      ])
    end

    it 'returns an empty array for short queries' do
      expect(catalog.search('3')).to eq([])
    end
  end
end
