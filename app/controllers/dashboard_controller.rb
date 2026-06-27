# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer_portal!

  def index
    @user = current_user
    scope = current_user.invoices

    today = Date.today
    month_range = today.beginning_of_month..today.end_of_month
    chart_range = (today - 29.days)..today

    @today_invoices = scope.where(invoice_date: today)
    @today_total = @today_invoices.sum(:total_amount).to_f
    @today_tax = @today_invoices.sum(:tax_amount).to_f

    @month_invoices = scope.where(invoice_date: month_range)
    @month_total = @month_invoices.sum(:total_amount).to_f
    @month_tax = @month_invoices.sum(:tax_amount).to_f

    @fbr_submitted_count = scope.where.not(fbr_invoice_id: [nil, '']).count
    @fbr_configured = current_user.can_submit_invoices?

    @recent_invoices = scope.includes(:items).order(created_at: :desc).limit(10)

    totals_by_date = scope.where(invoice_date: chart_range)
      .group(:invoice_date)
      .sum(:total_amount)

    @daily_chart_data = chart_range.index_with do |date|
      totals_by_date[date].to_f
    end

    @top_customers = scope.where(invoice_date: month_range)
      .group(:buyer_name)
      .order(Arel.sql('SUM(total_amount) DESC'))
      .limit(5)
      .sum(:total_amount)

    @unread_notifications = current_user.notifications.unread.count
  end

  def reports
    @start_date = parse_report_date(params[:start_date]) || Date.today.beginning_of_month
    @end_date = parse_report_date(params[:end_date]) || Date.today.end_of_month
    @end_date = @start_date if @end_date < @start_date

    base_invoices = current_user.invoices.where(invoice_date: @start_date..@end_date)

    @invoices = base_invoices.includes(:items).order(invoice_date: :desc)

    @summary = Reports::TaxSummary.for_user(current_user, start_date: @start_date, end_date: @end_date)
    @summary.merge!(
      draft: base_invoices.where(status: 'draft').count,
      failed: base_invoices.where(status: 'failed').count,
      fbr_submitted: base_invoices.where.not(fbr_invoice_id: [nil, '']).count
    )

    @daily_summary = base_invoices
      .group(Arel.sql('DATE(invoice_date)'))
      .order(Arel.sql('DATE(invoice_date)'))
      .sum(:total_amount)

    @customer_summary = base_invoices
      .group(:buyer_name)
      .sum(:total_amount)
      .sort_by { |_name, total| -total.to_f }
      .first(20)
      .to_h

    @status_breakdown = base_invoices.group(:status).count

    respond_to do |format|
      format.html
      format.csv do
        send_data Reports::TaxSummary.to_csv(@summary),
          filename: "tax-summary-#{@start_date}-#{@end_date}.csv",
          type: 'text/csv'
      end
    end
  end

  private

  def parse_report_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
