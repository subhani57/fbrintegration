# frozen_string_literal: true

class FbrValidationJob < ApplicationJob
  queue_as :fbr_invoices

  def perform(invoice_id)
    invoice = Invoice.includes(:items, :user).find(invoice_id)
    return if invoice.cancelled? || invoice.validated?
    return unless invoice.validating?

    user = invoice.user

    service = Fbr::ApiService.new(user, user.default_fbr_environment.to_sym)
    result = service.validate_invoice(invoice)

    if result[:success]
      invoice.safely_mark_validated!
    else
      invoice.update!(
        error_message: result[:error_message],
        fbr_status: 'failed'
      )
      invoice.mark_failed! if invoice.may_mark_failed?
    end

    invoice.broadcast_refresh_later_to(invoice)
  end
end
