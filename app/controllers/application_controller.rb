class ApplicationController < ActionController::Base
  include RoleAuthorization
  include Pundit::Authorization
  include RequestLogging

  protect_from_forgery with: :exception, prepend: true

  before_action :ensure_approved_user!, if: :user_signed_in?
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    elsif !resource.approved?
      pending_approval_path
    elsif resource.taxpayer? && resource.onboarding_step < 3
      onboarding_path
    elsif resource.viewer?
      dashboard_path
    else
      invoices_path
    end
  end

  private

  def ensure_approved_user!
    return if current_user.admin? || current_user.approved?
    return if devise_controller? || controller_name == 'pending_approval'

    redirect_to pending_approval_path, alert: 'Your account is pending admin approval.'
  end

  def user_not_authorized
    redirect_back fallback_location: root_path, alert: 'You are not authorized to perform this action.'
  end

  def handle_invalid_authenticity_token
    AppLogger.warn('request.csrf_failed', path: request.fullpath, method: request.request_method)
    redirect_back fallback_location: new_user_session_path, alert: 'Your session expired. Please sign in again.'
  end
end
