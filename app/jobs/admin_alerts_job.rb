# frozen_string_literal: true

class AdminAlertsJob < ApplicationJob
  queue_as :mailers

  def perform
    failed = Invoice.failed.where('updated_at > ?', 24.hours.ago).includes(:user)
    return if failed.empty?

    User.admins.find_each do |admin|
      UserMailer.admin_failed_submissions_alert(admin, failed.limit(20)).deliver_later
    end
  end
end
