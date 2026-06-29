# frozen_string_literal: true

module ManagedClientContext
  extend ActiveSupport::Concern

  included do
    helper_method :portal_user, :managed_client?
  end

  private

  def portal_user
    return @portal_user if defined?(@portal_user)

    @portal_user = if current_user&.accountant? && session[:managed_client_id].present?
                     current_user.clients.find_by(id: session[:managed_client_id]) || current_user
                   else
                     current_user
                   end
  end

  def managed_client?
    current_user&.accountant? && session[:managed_client_id].present?
  end

  def require_accountant!
    redirect_to root_path, alert: 'Accountant access only.' unless current_user&.accountant?
  end
end
