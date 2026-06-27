# frozen_string_literal: true

class MonthlyReportJob < ApplicationJob
  queue_as :mailers

  def perform
    period_end = Date.today.prev_month.end_of_month
    period_start = period_end.beginning_of_month

    User.taxpayers.find_each do |user|
      summary = Reports::TaxSummary.for_user(user, start_date: period_start, end_date: period_end)
      next if summary[:invoice_count].zero?

      ReportMailer.monthly_summary(user, summary).deliver_later
    end
  end
end
