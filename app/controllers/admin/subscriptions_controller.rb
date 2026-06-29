# frozen_string_literal: true

module Admin
  class SubscriptionsController < BaseController
    before_action :set_taxpayer, only: [:show, :mark_paid]

    def index
      @subscription_stats = Subscriptions::Manager.stats
      @revenue_stats = Subscriptions::RevenueStats.summary
      @taxpayers = User.taxpayers.order(:email).page(params[:page]).per(30)
      apply_subscription_filter!
    end

    def show
      @subscription_payments = @taxpayer.subscription_payments.includes(:recorded_by).recent.limit(20)
    end

    def receipt
      payment = SubscriptionPayment.find(params[:payment_id])
      send_data Subscriptions::ReceiptGenerator.new(payment).to_text,
                filename: "receipt-#{payment.receipt_number}.txt",
                type: 'text/plain'
    end

    def mark_paid
      if params[:period].present?
        months = Subscriptions::Manager::PERIOD_OPTIONS.fetch(params[:period].to_s)
        payment = @taxpayer.extend_subscription!(recorded_by: current_user, months: months)
        active_until = payment.active_until
        amount = payment.amount
      else
        active_until = Subscriptions::Manager.resolve_active_until(@taxpayer, active_until: params[:active_until])
        unless active_until
          redirect_back fallback_location: admin_subscription_path(@taxpayer), alert: 'Please select a valid active-until date.'
          return
        end

        payment = Subscriptions::Manager.record_payment!(
          user: @taxpayer,
          active_until: active_until,
          recorded_by: current_user
        )
        amount = payment.amount
      end

      AuditLog.record!(
        user: current_user,
        action: 'subscription.paid',
        auditable: @taxpayer,
        metadata: { active_until: active_until.iso8601, amount: amount },
        request: request
      )

      redirect_back(
        fallback_location: admin_subscription_path(@taxpayer),
        notice: "Payment of #{helpers.format_pkr(amount)} recorded. Access active until #{active_until.strftime('%d %b %Y')}."
      )
    rescue Subscriptions::Manager::Error => e
      redirect_back fallback_location: admin_subscription_path(@taxpayer), alert: e.message
    end

    private

    def set_taxpayer
      @taxpayer = User.taxpayers.find(params[:id])
    end

    def apply_subscription_filter!
      case params[:status].to_s
      when 'active'
        @taxpayers = @taxpayers.merge(User.subscription_active)
      when 'expired'
        @taxpayers = @taxpayers.merge(User.subscription_expired)
      when 'expiring_soon'
        @taxpayers = @taxpayers.merge(User.subscription_expiring_soon)
      when 'never_paid'
        @taxpayers = @taxpayers.where(subscription_active_until: nil)
      end
    end
  end
end
