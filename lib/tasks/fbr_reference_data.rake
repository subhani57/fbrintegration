# frozen_string_literal: true

namespace :fbr do
  namespace :reference_data do
    desc 'Warm HS codes cache from FBR (uses FBR_SANDBOX_TOKEN / FBR_PRODUCTION_TOKEN)'
    task warm_hs_codes: :environment do
      %w[sandbox production].each do |environment|
        cache_key = "fbr_hs_codes_#{Fbr::HsCodesCatalog::CACHE_VERSION}_#{environment}"
        Rails.cache.delete(cache_key)

        user = User.joins(:fbr_configurations)
                   .merge(FbrConfiguration.with_token.where(environment: environment))
                   .first
        user ||= User.new(default_fbr_environment: environment)

        codes = Fbr::HsCodesCatalog.for_user(user).all
        puts "[#{environment}] cached #{codes.size} HS codes"
      end
    end
  end
end
