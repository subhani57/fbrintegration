# frozen_string_literal: true

class ReportMailer < ApplicationMailer
  def monthly_summary(user, summary)
    @user = user
    @summary = summary
    mail(to: user.email, subject: "Monthly tax summary — #{summary[:period_label]}")
  end
end
