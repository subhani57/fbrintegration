# frozen_string_literal: true

module MailerConfig
  module_function

  def url_options
    host = production_host
    protocol = ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
    options = { host: host, protocol: protocol }

    unless Rails.env.production?
      options[:port] = ENV.fetch("APP_PORT", 3001).to_i
    end

    options
  end

  def production_host
    return ENV.fetch("APP_HOST", "localhost") unless Rails.env.production?

    ENV["APP_HOST"].presence ||
      heroku_app_host ||
      raise(KeyError, "APP_HOST must be set in production (e.g. your-app.herokuapp.com)")
  end

  def heroku_app_host
    name = ENV["HEROKU_APP_NAME"].presence
    return unless name

    "#{name}.herokuapp.com"
  end

  def smtp_configured?
    ENV["SMTP_ADDRESS"].present? ||
      ENV["SENDGRID_API_KEY"].present? ||
      ENV["MAILGUN_SMTP_SERVER"].present?
  end

  def smtp_settings
    return smtp_from_env if ENV["SMTP_ADDRESS"].present?
    return sendgrid_smtp_settings if ENV["SENDGRID_API_KEY"].present?
    return mailgun_smtp_settings if ENV["MAILGUN_SMTP_SERVER"].present?

    nil
  end

  def smtp_from_env
    {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: smtp_authentication,
      enable_starttls_auto: smtp_starttls?
    }.compact
  end

  def sendgrid_smtp_settings
    {
      address: ENV.fetch("SMTP_ADDRESS", "smtp.sendgrid.net"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV.fetch("SMTP_USERNAME", "apikey"),
      password: ENV["SENDGRID_API_KEY"],
      authentication: :plain,
      enable_starttls_auto: true,
      domain: production_host
    }
  end

  def mailgun_smtp_settings
    {
      address: ENV.fetch("MAILGUN_SMTP_SERVER"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV.fetch("MAILGUN_SMTP_LOGIN"),
      password: ENV.fetch("MAILGUN_SMTP_PASSWORD"),
      authentication: :plain,
      enable_starttls_auto: true
    }
  end

  def smtp_authentication
    auth = ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym
    auth == :none ? nil : auth
  end

  def smtp_starttls?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", true))
  end

  def delivery_error_message
    "Email could not be sent. The server is not configured for outgoing mail yet. " \
      "Please contact #{Branding::SUPPORT_EMAIL} for help resetting your password."
  end
end
