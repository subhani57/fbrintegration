module InvoiceGuard
  extend ActiveSupport::Concern

  def fbr_locked?(invoice)
    invoice.fbr_status == 'submitted' ||
      invoice.fbr_invoice_id.present? ||
      %w[submitted approved submitting].include?(invoice.status)
  end
end
