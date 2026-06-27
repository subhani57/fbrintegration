# config/initializers/fbr_config.rb
# FBR API Configuration — tokens must come from ENV / credentials (never hardcoded in production)

if Rails.env.development? && ENV['FBR_SANDBOX_TOKEN'].blank?
  Rails.application.config.after_initialize do
    AppLogger.warn('fbr.config.sandbox_token_missing')
  end
end

FBR_CONFIG = {
  sandbox: {
    base_url: 'https://gw.fbr.gov.pk/di_data/v1/di',
    token: ENV['FBR_SANDBOX_TOKEN'],
    endpoints: {
      post_invoice: 'postinvoicedata_sb',
      validate_invoice: 'validateinvoicedata_sb'
    }
  },
  production: {
    base_url: 'https://gw.fbr.gov.pk/di_data/v1/di',
    token: ENV['FBR_PRODUCTION_TOKEN'],
    endpoints: {
      post_invoice: 'postinvoicedata',
      validate_invoice: 'validateinvoicedata'
    }
  }
}.freeze
