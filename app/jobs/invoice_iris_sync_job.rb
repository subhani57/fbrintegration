# frozen_string_literal: true

class InvoiceIrisSyncJob < ApplicationJob
  queue_as :fbr_invoices
  retry_on Faraday::Error, wait: :exponentially_longer, attempts: 3
  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform(invoice_id, user_id = nil)
    invoice = Invoice.with_detail_associations.find_by(id: invoice_id)
    return unless invoice
    user = user_id ? User.find_by(id: user_id) : invoice.user
    return unless user

    result = Fbr::IrisInvoiceService.new(user).sync_invoice!(invoice)

    if result[:success]
      Notification.notify!(
        user,
        title: 'IRIS sync complete',
        body: result[:notice].presence || "Synced from IRIS (#{result[:source]}).",
        notification_type: 'success',
        link_path: "/invoices/#{invoice.id}"
      )
    else
      Notification.notify!(
        user,
        title: 'IRIS sync failed',
        body: result[:error_message].presence || 'Could not sync from IRIS.',
        notification_type: 'danger',
        link_path: "/invoices/#{invoice.id}"
      )
    end

    invoice.broadcast_refresh_later_to(invoice)
  ensure
    invoice&.clear_iris_syncing!
  end
end
