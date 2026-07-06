# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer_portal!

  def index
    @user = portal_user
    scope = portal_user.invoices.for_user_environment(portal_user)

    today = Date.today
    month_range = today.beginning_of_month..today.end_of_month
    chart_range = (today - 29.days)..today

    @today_invoices = scope.where(invoice_date: today)
    @today_amounts = Invoices::AmountSummary.for(@today_invoices)

    @month_invoices = scope.where(invoice_date: month_range)
    @month_amounts = Invoices::AmountSummary.for(@month_invoices)
    @month_tax = @month_amounts[:approved][:tax_amount]

    @fbr_submitted_count = scope.where.not(fbr_invoice_id: [nil, '']).count
    @fbr_configured = portal_user.can_submit_invoices?

    @recent_invoices = scope.order(created_at: :desc).limit(10)

    approved_chart_scope = scope.reporting_approved.where(invoice_date: chart_range)
    totals_by_date = approved_chart_scope.group(:invoice_date).sum(:total_amount)

    @daily_chart_data = chart_range.index_with do |date|
      totals_by_date[date].to_f
    end

    @top_customers = scope.reporting_approved
      .where(invoice_date: month_range)
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

    base_invoices = portal_user.invoices.for_user_environment(portal_user).where(invoice_date: @start_date..@end_date)

    @invoices = base_invoices.order(invoice_date: :desc)

    @summary = Reports::TaxSummary.for_user(portal_user, start_date: @start_date, end_date: @end_date)
    @amounts = Invoices::AmountSummary.for(base_invoices)

    @summary.merge!(
      draft: base_invoices.where(status: 'draft').count,
      failed: base_invoices.where(status: 'failed').count,
      cancelled: base_invoices.where(status: 'cancelled').count,
      fbr_submitted: base_invoices.where.not(fbr_invoice_id: [nil, '']).count,
      approved: @amounts[:approved],
      failed_cancelled: @amounts[:failed_cancelled]
    )

    @daily_summary = base_invoices.reporting_approved
      .group(Arel.sql('DATE(invoice_date)'))
      .order(Arel.sql('DATE(invoice_date)'))
      .sum(:total_amount)

    @failed_daily_summary = base_invoices.reporting_failed_or_cancelled
      .group(Arel.sql('DATE(invoice_date)'))
      .order(Arel.sql('DATE(invoice_date)'))
      .sum(:total_amount)

    @customer_summary = base_invoices.reporting_approved
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
