module RoleAuthorization
  extend ActiveSupport::Concern

  private

  def ensure_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: 'Access denied. Admin privileges required.'
  end

  def ensure_taxpayer!
    return if current_user&.taxpayer?

    redirect_to admin_dashboard_path, alert: 'This action requires a taxpayer account.'
  end

  def ensure_taxpayer_portal!
    return if current_user&.can_access_taxpayer_portal?

    redirect_to admin_dashboard_path, alert: 'This area is for taxpayer and viewer accounts only.'
  end

  def redirect_admin_from_taxpayer_portal!
    return unless current_user&.admin?

    redirect_to admin_dashboard_path,
                alert: 'Admins manage the system from the Admin Portal — invoice creation is for taxpayers only.'
  end
end
