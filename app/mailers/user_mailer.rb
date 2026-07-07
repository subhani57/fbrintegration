# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def account_approved(user)
    @user = user
    mail(to: user.email, subject: "Your #{Branding::APP_SHORT_NAME} account has been approved")
  end

  def admin_failed_submissions_alert(admin, invoices)
    @admin = admin
    @invoices = invoices
    mail(to: admin.email, subject: 'Taxpayers with failed FBR submissions')
  end
end
