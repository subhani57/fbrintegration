# frozen_string_literal: true

module SubscriptionAccess
  extend ActiveSupport::Concern

  included do
    before_action :ensure_subscription_active!, if: :user_signed_in?
    before_action :warn_subscription_expiring_soon, if: :user_signed_in?
  end

  private

  def ensure_subscription_active!
    return unless subscription_required?

    redirect_to subscription_required_path, alert: subscription_blocked_message
  end

  def warn_subscription_expiring_soon
    return unless current_user.taxpayer?
    return unless current_user.approved?
    return unless current_user.subscription_active?
    return unless current_user.subscription_expiring_soon?
    return if subscription_exempt_controller?

    @subscription_expiring_soon = true
    @subscription_days_remaining = current_user.subscription_days_remaining
  end

  def subscription_required?
    return false if current_user.admin? || current_user.viewer? || current_user.accountant?
    return false unless current_user.taxpayer?
    return false unless current_user.approved?
    return false if subscription_exempt_controller?

    current_user.subscription_expired?
  end

  def subscription_exempt_controller?
    devise_controller? ||
      controller_name.in?(%w[pending_approval subscription_required])
  end

  def subscription_blocked_message
    fee = ApplicationController.helpers.format_pkr(current_user.monthly_subscription_fee)
    "Please pay #{fee} to continue access. Contact your administrator to record payment."
  end
end
