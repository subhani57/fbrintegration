# frozen_string_literal: true

module InvoiceRecordLoading
  extend ActiveSupport::Concern

  private

  def find_portal_invoice(id)
    portal_user.invoices.for_user_environment(portal_user).includes(includes_for_invoice_action).find(id)
  end

  def includes_for_invoice_action
    includes = [:items]
    includes << :user if invoice_action_needs_user?
    includes
  end

  def invoice_action_needs_user?
    action_name == 'download_pdf' ||
      (action_name == 'show' && request.format.pdf?)
  end
end
