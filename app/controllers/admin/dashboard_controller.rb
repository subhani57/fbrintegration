module Admin
  class DashboardController < BaseController
    def index
      @users_count = User.count
      @taxpayers_count = User.taxpayers.count
      @invoices_count = Invoice.count
      @submitted_count = Invoice.where(fbr_status: 'submitted').count
      @failed_count = Invoice.where(status: 'failed').count

      order_col = User.column_names.include?('created_at') ? 'created_at' : 'id'
      @recent_users = User.order(order_col => :desc).limit(10)
      @recent_invoices = Invoice.includes(:user).order(created_at: :desc).limit(10)
      @failed_invoices = Invoice.includes(:user).where(status: 'failed').order(updated_at: :desc).limit(5)
    end
  end
end
