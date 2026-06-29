# frozen_string_literal: true

module Subscriptions
  class ReceiptGenerator
    def initialize(payment)
      @payment = payment
      @user = payment.user
    end

    def to_text
      <<~TEXT
        FBR Digital Invoicing — Payment Receipt
        Receipt #: #{@payment.receipt_number}
        Date: #{@payment.created_at.strftime('%d %B %Y')}
        Taxpayer: #{@user.email}
        Amount: Rs. #{format('%.2f', @payment.amount)}
        Active until: #{@payment.active_until.strftime('%d %B %Y')}
        Notes: #{@payment.notes.presence || '—'}
      TEXT
    end
  end
end
