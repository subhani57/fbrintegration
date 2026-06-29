source "https://rubygems.org"

ruby "3.4.7"

gem "rails", "~> 8.1.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# UI & Frontend
gem "devise"
gem "haml-rails"
gem "bootstrap", "~> 5.3"
gem "font-awesome-sass"
gem "jquery-rails"
gem "simple_form"
gem "sassc-rails", "~> 2.1"

# FBR Integration
gem "httparty"
gem "faraday"
gem "faraday-retry"
gem "jwt"
gem "prawn"
gem "prawn-table"
gem "wicked_pdf"
gem "rqrcode"
gem "barby"
gem "chunky_png"
gem "figaro"

# Background Jobs
gem "sidekiq"
gem "sidekiq-scheduler"
gem "redis-rails"

# File Upload
gem "carrierwave", "~> 3.0"
gem "mini_magick"

# Utilities
gem "aasm"
gem "pundit"
gem "kaminari"
gem "chartkick"
gem "groupdate"
gem "whenever", require: false
gem "rubyzip", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "dotenv-rails"
  gem "pry-rails"
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails"
  gem "faker"
  gem "webmock"
  gem "vcr"
end

group :development do
  gem "web-console"
  gem "better_errors"
  gem "binding_of_caller"
  gem "annotate"
  gem "bullet"
  gem "letter_opener"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
