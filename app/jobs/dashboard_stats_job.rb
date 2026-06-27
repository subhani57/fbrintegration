# frozen_string_literal: true

class DashboardStatsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 2

  def perform
    User.taxpayers.find_each do |user|
      stats = {
        today_total: user.invoices.today.sum(:total_amount).to_f,
        month_total: user.invoices.this_month.sum(:total_amount).to_f,
        submitted_count: user.invoices.submitted.count,
        updated_at: Time.current.iso8601
      }
      Rails.cache.write("dashboard_stats/#{user.id}", stats, expires_in: 20.minutes)
    end
  end
end
