# frozen_string_literal: true

module Admin
  class SubscriptionPlansController < BaseController
    def index
      @plans = SubscriptionPlan.order(:monthly_fee)
      @users_by_plan = User.group(:subscription_plan_id).count
    end

    def update
      @plan = SubscriptionPlan.find(params[:id])
      if @plan.update(plan_params)
        redirect_to admin_subscription_plans_path, notice: 'Plan updated.'
      else
        redirect_to admin_subscription_plans_path, alert: @plan.errors.full_messages.join(', ')
      end
    end

    private

    def plan_params
      params.require(:subscription_plan).permit(:monthly_fee, :invoice_limit, :active, features: {})
    end
  end
end
