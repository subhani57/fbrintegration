# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  def submission_success(invoice)
    @invoice = invoice
    @user = invoice.user
    mail(to: @user.email, subject: "#{Branding::APP_SHORT_NAME} — FBR invoice submitted: #{@invoice.invoice_number}")
  end

  def submission_failed(invoice)
    @invoice = invoice
    @user = invoice.user
    mail(to: @user.email, subject: "#{Branding::APP_SHORT_NAME} — FBR submission failed: #{@invoice.invoice_number}")
  end
end
