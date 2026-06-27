# frozen_string_literal: true

class CleanupLogsJob < ApplicationJob
  queue_as :default

  def perform(days: 90)
    deleted = FbrLog.cleanup!(days: days)
    AppLogger.info('maintenance.cleanup_logs', deleted_count: deleted, retention_days: days)
  end
end
