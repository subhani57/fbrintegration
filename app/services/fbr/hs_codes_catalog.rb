# frozen_string_literal: true

module Fbr
  class HsCodesCatalog
    CACHE_VERSION = 'v2'
    CACHE_TTL = 24.hours

    def self.for_user(user)
      new(user)
    end

    def initialize(user)
      @user = user
    end

    def all
      cached = Rails.cache.read(cache_key)
      return cached if cached.is_a?(Array) && cached.any?

      codes = fetch_and_normalize
      if codes.any?
        Rails.cache.write(cache_key, codes, expires_in: CACHE_TTL)
      else
        AppLogger.warn(
          'fbr.hs_codes_catalog.empty',
          user_id: @user&.id,
          environment: environment,
          system_token_present: system_token_present?
        )
      end
      codes
    end

    def search(query)
      q = query.to_s.strip.downcase
      return [] if q.length < 2

      all.select do |item|
        code = (item[:code] || item['code']).to_s.downcase
        desc = (item[:description] || item['description']).to_s.downcase
        code.include?(q) || desc.include?(q)
      end.first(50)
    end

    private

    def cache_key
      "fbr_hs_codes_#{CACHE_VERSION}_#{environment}"
    end

    def environment
      @user&.default_fbr_environment.presence || 'sandbox'
    end

    def system_token_present?
      token_key = environment == 'production' ? 'FBR_PRODUCTION_TOKEN' : 'FBR_SANDBOX_TOKEN'
      ENV[token_key].present? || ENV['FBR_SANDBOX_TOKEN'].present? || ENV['FBR_PRODUCTION_TOKEN'].present?
    end

    def fetch_and_normalize
      raw = fetch_items_with_fallback
      normalize(raw)
    rescue StandardError => e
      AppLogger.error('fbr.hs_codes_catalog.fetch_failed', exception: e, user_id: @user&.id)
      []
    end

    def fetch_items_with_fallback
      token_strategies.each do |service|
        data = service.items
        return data if extract_array(data).any?
      end

      nil
    end

    def token_strategies
      primary = environment
      alternate = primary == 'production' ? 'sandbox' : 'production'

      [
        Fbr::ReferenceService.new(@user, prefer_system_token: false, environment: primary),
        Fbr::ReferenceService.new(@user, prefer_system_token: true, environment: primary),
        Fbr::ReferenceService.new(@user, prefer_system_token: true, environment: alternate)
      ]
    end

    def normalize(data)
      extract_array(data).filter_map do |item|
        next unless item.is_a?(Hash)

        code = item['hS_CODE'] || item['HS_CODE'] || item['hs_code'] || item['code'] || item['hscode']
        next if code.blank?

        {
          code: code.to_s,
          description: (item['description'] || item['DESCRIPTION'] || item['desc'] || '').to_s
        }
      end.then { |codes| HsCodeSorting.sort_codes(codes) }
    end

    def extract_array(data)
      return data if data.is_a?(Array)
      return [] if data.blank?
      return [] unless data.is_a?(Hash)

      data['data'] || data['items'] || data['result'] || data.values.find { |value| value.is_a?(Array) } || []
    end
  end
end
