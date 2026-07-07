# frozen_string_literal: true

module Admin
  class SubscriptionsController < BaseController
    before_action :set_taxpayer, only: [:show, :mark_paid, :mark_free_forever, :generate_receipt, :reduce_months]

    def index
      @subscription_stats = Subscriptions::Manager.stats
      @revenue_stats = Subscriptions::RevenueStats.summary
      @taxpayers = User.taxpayers.order(:email).page(params[:page]).per(30)
      apply_subscription_filter!
    end

    def show
      @subscription_payments = @taxpayer.subscription_payments.includes(:recorded_by, :line_items).recent.limit(20)
    end

    def receipt
      payment = SubscriptionPayment.includes(:user, :recorded_by, :line_items).find(params[:payment_id])
      generator = Subscriptions::ReceiptGenerator.new(payment)
      send_data generator.to_pdf,
                filename: generator.filename,
                type: generator.content_type,
                disposition: 'attachment'
    end

    def generate_receipt
      result = Subscriptions::ReceiptBuilder.call(
        user: @taxpayer,
        recorded_by: current_user,
        months: params[:months],
        monthly_fee: params[:monthly_fee],
        active_until: params[:active_until],
        extra_lines: extra_lines_from_params,
        notes: params[:notes]
      )
      payment = result[:payment]

      AuditLog.record!(
        user: current_user,
        action: 'subscription.receipt_generated',
        auditable: @taxpayer,
        metadata: {
          payment_id: payment.id,
          receipt_number: payment.receipt_number,
          amount: payment.amount,
          active_until: payment.active_until.iso8601
        },
        request: request
      )

      redirect_to admin_subscription_path(
        @taxpayer,
        download_receipt: payment.id
      ),
                  notice: "Unpaid receipt #{payment.receipt_number} generated for #{helpers.format_pkr(payment.amount)}. Mark as paid when payment is received."
    rescue Subscriptions::ReceiptBuilder::Error, Subscriptions::Manager::Error => e
      redirect_back fallback_location: admin_subscription_path(@taxpayer), alert: e.message
    end

    def mark_receipt_paid
      payment = SubscriptionPayment.find(params[:payment_id])
      taxpayer = payment.user
      unless taxpayer.taxpayer?
        redirect_back fallback_location: admin_subscriptions_path, alert: 'Invalid taxpayer.'
        return
      end

      Subscriptions::Manager.mark_receipt_paid!(payment, recorded_by: current_user)
      AuditLog.record!(
        user: current_user,
        action: 'subscription.receipt_paid',
        auditable: taxpayer,
        metadata: {
          payment_id: payment.id,
          receipt_number: payment.receipt_number,
          amount: payment.amount,
          active_until: payment.active_until.iso8601
        },
        request: request
      )

      redirect_to admin_subscription_path(taxpayer),
                  notice: "Receipt #{payment.receipt_number} marked paid. Access active until #{payment.active_until.strftime('%d %b %Y')}."
    rescue Subscriptions::Manager::Error => e
      redirect_back fallback_location: admin_subscription_path(payment&.user || @taxpayer), alert: e.message
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

    def reduce_months
      if params[:reduce_period].present?
        months = Subscriptions::Manager::REDUCE_PERIOD_OPTIONS.fetch(params[:reduce_period].to_s)
        adjustment = @taxpayer.reduce_subscription!(recorded_by: current_user, months: months)
        new_until = adjustment.active_until
      else
        new_until = Subscriptions::Manager.resolve_reduce_until(@taxpayer, active_until: params[:reduce_active_until])
        unless new_until
          redirect_back fallback_location: admin_subscription_path(@taxpayer), alert: 'Please select a valid reduce-to date.'
          return
        end

        adjustment = @taxpayer.reduce_subscription!(recorded_by: current_user, active_until: new_until)
      end

      AuditLog.record!(
        user: current_user,
        action: 'subscription.reduced',
        auditable: @taxpayer,
        metadata: { active_until: new_until.iso8601 },
        request: request
      )

      redirect_back(
        fallback_location: admin_subscription_path(@taxpayer),
        notice: "Subscription reduced. Access now active until #{new_until.strftime('%d %b %Y')}."
      )
    rescue Subscriptions::Manager::Error => e
      redirect_back fallback_location: admin_subscription_path(@taxpayer), alert: e.message
    end

    def mark_free_forever
      if @taxpayer.subscription_free_forever?
        redirect_to admin_subscription_path(@taxpayer), notice: 'This account is already marked free forever.'
        return
      end

      @taxpayer.grant_free_forever!(recorded_by: current_user)
      AuditLog.record!(user: current_user, action: 'subscription.free_forever', auditable: @taxpayer, request: request)
      redirect_to admin_subscription_path(@taxpayer), notice: "#{@taxpayer.email} is now free forever."
    rescue Subscriptions::Manager::Error => e
      redirect_to admin_subscription_path(@taxpayer), alert: e.message
    end

    private

    def set_taxpayer
      scope = User.taxpayers
      scope = scope.includes(:subscription_plan) if action_name == 'show'
      @taxpayer = scope.find(params[:id])
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

    def extra_lines_from_params
      descriptions = Array(params[:extra_line_descriptions])
      amounts = Array(params[:extra_line_amounts])

      descriptions.zip(amounts).map do |description, amount|
        { description: description, amount: amount }
      end
    end
  end
end
