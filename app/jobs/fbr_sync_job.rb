# frozen_string_literal: true

class FbrSyncJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(user_id = nil)
    scope = user_id ? User.where(id: user_id) : User.taxpayers
    synced = 0

    scope.includes(:fbr_configurations).find_each do |user|
      next unless user.configuration_for(user.default_fbr_environment)&.token_configured?

      user.invoices.where.not(fbr_invoice_id: nil).where(fbr_status: 'submitted').find_each do |invoice|
        service = Fbr::IrisInvoiceService.new(user)
        result = service.sync_invoice!(invoice)
        synced += 1 if result[:success]
      rescue StandardError => e
        AppLogger.warn('fbr.sync.invoice_skipped', exception: e, invoice_id: invoice.id, user_id: user.id)
      end
    end

    AppLogger.info('fbr.sync.completed', synced_count: synced, user_id: user_id)
  end
end
