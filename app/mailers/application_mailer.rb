# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: Branding::MAILER_FROM
  layout 'mailer'
end
