# frozen_string_literal: true

module FbrSubmissionGuard
  extend ActiveSupport::Concern

  private

  def ensure_fbr_submission_allowed!
    invoice = @invoice if defined?(@invoice) && @invoice.present?
    reason = Fbr::EnvironmentGuard.submission_blocked_reason(current_user, invoice: invoice)
    return if reason.blank?

    redirect_to(invoice ? invoice_path(invoice) : invoices_path, alert: reason)
  end
end
