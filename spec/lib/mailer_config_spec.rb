# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailerConfig do
  describe '.smtp_configured?' do
    it 'is true when SMTP_ADDRESS is set' do
      climate_control SMTP_ADDRESS: 'smtp.example.com' do
        expect(described_class.smtp_configured?).to be true
      end
    end

    it 'is true when SENDGRID_API_KEY is set' do
      climate_control SENDGRID_API_KEY: 'sg.test' do
        expect(described_class.smtp_configured?).to be true
      end
    end
  end

  describe '.smtp_settings' do
    it 'builds SendGrid settings from the API key' do
      climate_control SMTP_ADDRESS: nil, SMTP_USERNAME: nil, SMTP_PASSWORD: nil,
                        SENDGRID_API_KEY: 'sg.test-key', APP_HOST: 'app.example.com' do
        settings = described_class.smtp_settings

        expect(settings[:address]).to eq('smtp.sendgrid.net')
        expect(settings[:user_name]).to eq('apikey')
        expect(settings[:password]).to eq('sg.test-key')
      end
    end
  end

  describe '.production_host' do
    it 'falls back to the Heroku app hostname' do
      climate_control HEROKU_APP_NAME: 'fbr-integration-cf69013f2b10', APP_HOST: nil do
        allow(Rails.env).to receive(:production?).and_return(true)

        expect(described_class.production_host).to eq('fbr-integration-cf69013f2b10.herokuapp.com')
      end
    end
  end

  def climate_control(vars)
    original = {}
    vars.each do |key, value|
      key = key.to_s
      original[key] = ENV.key?(key) ? ENV[key] : :missing
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    original.each do |key, value|
      value == :missing ? ENV.delete(key) : ENV[key] = value
    end
  end
end
