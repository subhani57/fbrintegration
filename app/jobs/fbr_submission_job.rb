# app/jobs/fbr_submission_job.rb
class FbrSubmissionJob < ApplicationJob
  queue_as :fbr_invoices
  retry_on Faraday::Error, wait: :exponentially_longer, attempts: 5
  retry_on StandardError, wait: 1.minute, attempts: 3

  def perform(invoice_id, environment = nil)
    invoice = Invoice.find(invoice_id)
    return if invoice.cancelled? || invoice.fbr_invoice_id.present?
    return unless invoice.submitting? || invoice.validated?

    env = environment&.to_sym || invoice.user.default_fbr_environment.to_sym
    result = invoice.submit_to_fbr_api!(environment: env)

    unless result
      invoice.increment!(:retry_count)
      invoice.mark_failed! if invoice.retry_count >= 3 && invoice.may_mark_failed?
    end

    invoice.broadcast_refresh_later_to(invoice)
  end
end
