# config/initializers/fbr_config.rb
# FBR API Configuration — tokens must come from ENV / credentials (never hardcoded in production)

if Rails.env.development? && ENV['FBR_SANDBOX_TOKEN'].blank?
  Rails.application.config.after_initialize do
    AppLogger.warn('fbr.config.sandbox_token_missing')
  end
end
