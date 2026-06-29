# frozen_string_literal: true

module Invoices
  class ConnectorImport
    def initialize(user, connector)
      @user = user
      @connector = connector
    end

    def call(payload)
      data = payload.is_a?(Hash) ? payload.with_indifferent_access : JSON.parse(payload).with_indifferent_access
      invoice = @user.invoices.create!(
        invoice_date: data[:invoice_date] || Date.current,
        invoice_type: data[:invoice_type] || 'Sale Invoice',
        buyer_name: data[:buyer_name],
        buyer_ntn: data[:buyer_ntn],
        buyer_province: data[:buyer_province] || Company::DEFAULT_PROVINCE,
        buyer_address: data[:buyer_address],
        buyer_registration_type: data[:buyer_registration_type] || Invoice::DEFAULT_BUYER_REGISTRATION_TYPE,
        test_data: { connector: @connector.provider, imported_at: Time.current.iso8601 }
      )
      Array(data[:items]).each do |item|
        invoice.items.create!(item.slice('description', 'hs_code', 'quantity', 'uom', 'unit_price', 'tax_rate', 'sale_type'))
      end
      invoice
    end
  end
end
