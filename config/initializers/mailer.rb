# frozen_string_literal: true

if Rails.env.production? && !MailerConfig.smtp_configured?
  Rails.logger.warn(
    "[mailer] Outgoing email is not configured. Set SMTP_ADDRESS or SENDGRID_API_KEY on Heroku " \
    "for password reset and notification emails."
  )
end
