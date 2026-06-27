class RootController < ApplicationController
  def index
    if user_signed_in?
      if current_user.admin?
        redirect_to admin_dashboard_path
      elsif current_user.viewer?
        redirect_to dashboard_path
      else
        redirect_to invoices_path
      end
    else
      redirect_to new_user_session_path
    end
  end
end
