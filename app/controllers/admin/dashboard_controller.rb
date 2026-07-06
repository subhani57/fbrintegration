module Admin
  class DashboardController < BaseController
    def index
      reportable_invoices = Invoice.excluding_sandbox_tests

      @users_count = User.count
      @taxpayers_count = User.taxpayers.count
      @invoices_count = reportable_invoices.count
      @submitted_count = reportable_invoices.where(fbr_status: 'submitted').count
      @failed_count = reportable_invoices.where(status: 'failed').count
      @subscription_stats = Subscriptions::Manager.stats
      @expiring_taxpayers = User.taxpayers.subscription_expiring_soon.order(:subscription_active_until).limit(5)
      @expired_taxpayers = User.taxpayers.subscription_expired.order(:subscription_active_until).limit(5)

      order_col = User.column_names.include?('created_at') ? 'created_at' : 'id'
      @recent_users = User.order(order_col => :desc).limit(10)
      @recent_invoices = reportable_invoices.with_user.order(created_at: :desc).limit(10)
      @failed_invoices = reportable_invoices.with_user.where(status: 'failed').order(updated_at: :desc).limit(5)
    end
  end
end
