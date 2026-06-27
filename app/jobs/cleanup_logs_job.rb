# frozen_string_literal: true

class CleanupLogsJob < ApplicationJob
  queue_as :default

  def perform(days: 90)
    deleted = FbrLog.cleanup!(days: days)
    Rails.logger.info "CleanupLogsJob removed #{deleted} FBR log(s) older than #{days} days"
  end
end
