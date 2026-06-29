# frozen_string_literal: true

module MailerConfig
  module_function

  def url_options
    host = if Rails.env.production?
             ENV.fetch("APP_HOST")
           else
             ENV.fetch("APP_HOST", "localhost")
           end
    protocol = ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
    options = { host: host, protocol: protocol }

    unless Rails.env.production?
      options[:port] = ENV.fetch("APP_PORT", 3000).to_i
    end

    options
  end

  def smtp_settings
    {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  end

  def smtp_configured?
    ENV["SMTP_ADDRESS"].present?
  end
end
