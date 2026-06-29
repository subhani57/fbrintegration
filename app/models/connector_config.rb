# frozen_string_literal: true

class ConnectorConfig < ApplicationRecord
  PROVIDERS = %w[shopify woocommerce custom_webhook tally_export].freeze

  belongs_to :user

  validates :name, :provider, presence: true
  validates :provider, inclusion: { in: PROVIDERS }

  scope :active, -> { where(active: true) }

  def ingest_payload!(payload)
    Invoices::ConnectorImport.new(user, self).call(payload)
  end
end
