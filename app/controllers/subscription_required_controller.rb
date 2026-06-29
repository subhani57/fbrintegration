# frozen_string_literal: true

class SubscriptionRequiredController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :ensure_subscription_active!
  skip_before_action :warn_subscription_expiring_soon

  def show
    redirect_to root_path unless current_user.taxpayer?
    redirect_to root_path if current_user.subscription_active?
    @last_payment = current_user.subscription_payments.recent.first
  end
end
