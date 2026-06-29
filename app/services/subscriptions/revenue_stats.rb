# frozen_string_literal: true

module Subscriptions
  class RevenueStats
    def self.summary
      payments = SubscriptionPayment.where('created_at >= ?', Date.current.beginning_of_month)
      {
        mrr: User.taxpayers.subscription_active.count * (SubscriptionPlan.default&.monthly_fee || User::MONTHLY_SUBSCRIPTION_FEE),
        collected_this_month: payments.sum(:amount),
        payments_this_month: payments.count,
        active_subscribers: User.taxpayers.subscription_active.count,
        expired_subscribers: User.taxpayers.subscription_expired.count
      }
    end
  end
end
