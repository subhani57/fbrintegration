# frozen_string_literal: true

class RecurringInvoiceJob < ApplicationJob
  queue_as :default

  def perform
    RecurringInvoice.due.find_each do |recurring|
      recurring.run!
      Notification.notify!(
        recurring.user,
        title: 'Recurring invoice created',
        body: "Draft invoice \"#{recurring.name}\" was generated.",
        notification_type: 'info',
        link_path: '/invoices'
      )
    rescue StandardError => e
      AppLogger.error('recurring_invoice.failed', exception: e, recurring_id: recurring.id)
    end
  end
end
