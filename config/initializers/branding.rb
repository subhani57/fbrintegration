# frozen_string_literal: true

module Branding
  COMPANY_NAME = 'Integron Technologies'
  PRODUCT_NAME = 'FBR Digital Invoicing'
  APP_SHORT_NAME = 'Integron'
  APP_NAME = "#{COMPANY_NAME} — #{PRODUCT_NAME}"
  ADMIN_APP_NAME = "#{COMPANY_NAME} Admin"
  TAGLINE = 'Create, validate, and submit sales tax invoices to the Federal Board of Revenue — all in one place.'
  FOOTER_LINE = "#{COMPANY_NAME} · #{PRODUCT_NAME}"
  SUPPORT_EMAIL = ENV.fetch('SUPPORT_EMAIL', 'support@integrontechnologies.com')
  MAILER_FROM = ENV.fetch('MAILER_FROM', ENV.fetch('DEFAULT_FROM_EMAIL', 'noreply@integrontechnologies.com'))
  SMS_PREFIX = APP_SHORT_NAME
  PDF_FOOTER = COMPANY_NAME
end
