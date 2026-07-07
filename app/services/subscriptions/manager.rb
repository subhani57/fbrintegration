# frozen_string_literal: true

module Subscriptions
  class Manager
    EXPIRING_SOON_DAYS = 7
    FOREVER_FREE_PAYMENT_UNTIL = Date.new(2099, 12, 31)
    TRIAL_DAYS = 7
    PERIOD_OPTIONS = {
      '1' => 1,
      '3' => 3,
      '6' => 6,
      '12' => 12
    }.freeze
    REDUCE_PERIOD_OPTIONS = {
      '1' => 1,
      '3' => 3,
      '6' => 6
    }.freeze

    class Error < StandardError; end

    class << self
      def stats
        taxpayers = User.taxpayers
        {
          active: taxpayers.subscription_active.count,
          expired: taxpayers.subscription_expired.count,
          expiring_soon: taxpayers.subscription_expiring_soon.count,
          never_paid: taxpayers.where(subscription_active_until: nil).count
        }
      end

      def grant_trial!(user, recorded_by: nil, days: TRIAL_DAYS)
        return unless user.taxpayer?
        return if user.subscription_payments.paid.exists?

        active_until = Date.current + days.days
        record_payment!(
          user: user,
          active_until: active_until,
          recorded_by: recorded_by,
        amount: 0,
        period_months: 0,
        notes: "#{days}-day trial on account approval"
        )
      end

      def grant_free_forever!(user, recorded_by:)
        raise Error, 'Subscriptions apply to taxpayer accounts only.' unless user.taxpayer?
        return user if user.subscription_free_forever?

        user.transaction do
          user.update!(subscription_free_forever: true)
          user.subscription_payments.create!(
            recorded_by: recorded_by,
            amount: 0,
            active_until: FOREVER_FREE_PAYMENT_UNTIL,
            notes: 'Forever free access granted by admin',
            status: 'paid',
            paid_at: Time.current
          )
        end

        Notification.notify!(
          user,
          title: 'Forever free access granted',
          body: "Your account now has unlimited free access to #{Branding::PRODUCT_NAME}.",
          notification_type: 'success',
          link_path: '/dashboard'
        )
        AppLogger.info(
          'subscription.free_forever_granted',
          user_id: user.id,
          recorded_by_id: recorded_by.id
        )
        user
      end

      def record_payment!(user:, active_until:, recorded_by:, amount: nil, notes: nil, period_months: nil,
                          months: nil, monthly_fee: nil, line_items: nil, status: 'paid')
        raise Error, 'Subscriptions apply to taxpayer accounts only.' unless user.taxpayer?
        raise Error, 'Active until date must be today or in the future.' if active_until < Date.current
        raise Error, 'Invalid payment status.' unless status.in?(SubscriptionPayment::STATUSES)

        period_months ||= months || infer_period_months(user, active_until)
        amount ||= period_months * user.monthly_subscription_fee

        payment = nil
        user.transaction do
          previous_until = user.subscription_active_until
          user.update!(subscription_active_until: active_until) if status == 'paid'
          payment = user.subscription_payments.new(
            recorded_by: recorded_by,
            amount: amount,
            active_until: active_until,
            months: months,
            monthly_fee: monthly_fee,
            notes: notes.presence || payment_note_for(status, period_months, previous_until),
            status: status,
            paid_at: (Time.current if status == 'paid')
          )
          build_line_items!(payment, line_items) if line_items.present?
          payment.save!
        end

        notify_payment_recorded!(user, payment) if payment.paid?
        AppLogger.info(
          'subscription.payment_recorded',
          user_id: user.id,
          recorded_by_id: recorded_by.id,
          active_until: active_until,
          amount: amount,
          period_months: period_months
        )
        payment
      end

      def extend!(user:, recorded_by:, months: 1, active_until: nil)
        until_date = active_until || extension_base_date(user) + months.months
        record_payment!(
          user: user,
          active_until: until_date,
          recorded_by: recorded_by,
          period_months: months,
          status: 'paid'
        )
      end

      def mark_receipt_paid!(payment, recorded_by:)
        raise Error, 'Subscriptions apply to taxpayer accounts only.' unless payment.user.taxpayer?
        raise Error, 'This receipt is already marked paid.' unless payment.pending?
        raise Error, 'Active until date must be today or in the future.' if payment.active_until < Date.current

        user = payment.user
        user.transaction do
          user.update!(subscription_active_until: payment.active_until)
          payment.update!(
            status: 'paid',
            paid_at: Time.current,
            recorded_by: recorded_by
          )
        end

        notify_payment_recorded!(user, payment)
        AppLogger.info(
          'subscription.receipt_marked_paid',
          user_id: user.id,
          payment_id: payment.id,
          recorded_by_id: recorded_by.id,
          active_until: payment.active_until
        )
        payment
      end

      def resolve_active_until(user, active_until: nil, period: nil)
        return Date.parse(active_until.to_s) if active_until.present?

        months = PERIOD_OPTIONS.fetch(period.to_s, 1)
        extension_base_date(user) + months.months
      rescue ArgumentError
        nil
      end

      def remind_expiring_users!
        reminded = 0

        User.taxpayers.subscription_expiring_soon.find_each do |user|
          next if reminder_sent_today?(user, 'subscription.expiring_soon')

          Notification.notify!(
            user,
            title: 'Subscription expiring soon',
            body: "Your access expires on #{user.subscription_active_until.strftime('%d %B %Y')}. " \
                  "Please pay #{format_amount(user.monthly_subscription_fee)} to continue.",
            notification_type: 'warning',
            link_path: '/subscription_required'
          )
          mark_reminder_sent!(user, 'subscription.expiring_soon')
          Notifications::SmsDelivery.deliver(user, "#{Branding::SMS_PREFIX}: subscription expires #{user.subscription_active_until.strftime('%d %b %Y')}.")
          reminded += 1
        end

        User.taxpayers.subscription_expired.find_each do |user|
          next if reminder_sent_today?(user, 'subscription.expired')

          Notification.notify!(
            user,
            title: 'Subscription expired',
            body: "Please pay #{format_amount(user.monthly_subscription_fee)} to restore access.",
            notification_type: 'danger',
            link_path: '/subscription_required'
          )
          mark_reminder_sent!(user, 'subscription.expired')
          reminded += 1
        end

        AppLogger.info('subscription.reminders_sent', count: reminded)
        reminded
      end

      def reduce!(user:, recorded_by:, months: nil, active_until: nil)
        raise Error, 'Subscriptions apply to taxpayer accounts only.' unless user.taxpayer?
        raise Error, 'Forever free accounts cannot be reduced.' if user.subscription_free_forever?
        raise Error, 'No subscription end date to reduce.' if user.subscription_active_until.blank?

        previous_until = user.subscription_active_until
        new_until = if active_until.present?
                      Date.parse(active_until.to_s)
                    else
                      months = months.presence || 1
                      previous_until - months.months
                    end
        raise Error, 'New date must be before the current expiry date.' if new_until >= previous_until
        raise Error, 'Please select a valid active-until date.' if new_until.blank?

        inferred_months = months || [((previous_until - new_until).to_i / 30.0).round, 1].max
        adjustment = apply_subscription_adjustment!(
          user: user,
          recorded_by: recorded_by,
          active_until: new_until,
          months: -inferred_months,
          notes: reduction_note(previous_until, new_until, inferred_months)
        )

        AppLogger.info(
          'subscription.reduced',
          user_id: user.id,
          recorded_by_id: recorded_by.id,
          previous_until: previous_until,
          active_until: new_until,
          months: inferred_months
        )
        adjustment
      rescue ArgumentError
        raise Error, 'Please select a valid active-until date.'
      end

      def resolve_reduce_until(user, active_until: nil, period: nil)
        return Date.parse(active_until.to_s) if active_until.present?

        months = REDUCE_PERIOD_OPTIONS.fetch(period.to_s, 1)
        user.subscription_active_until - months.months
      rescue ArgumentError
        nil
      end

      def extension_base_date(user)
        [user.subscription_active_until, Date.current].compact.max
      end

      private

      def build_line_items!(payment, line_items)
        line_items.each do |item|
          payment.line_items.build(
            description: item[:description],
            quantity: item[:quantity] || 1,
            unit_amount: item[:unit_amount] || item[:amount],
            amount: item[:amount],
            position: item[:position] || 0
          )
        end
      end

      def infer_period_months(user, active_until)
        days = (active_until - extension_base_date(user)).to_i
        [[(days / 30.0).round, 1].max, 12].min
      end

      def default_payment_note(period_months, previous_until)
        parts = ["#{period_months} month(s)"]
        parts << "extended from #{previous_until.strftime('%d %b %Y')}" if previous_until.present?
        parts.join(' · ')
      end

      def payment_note_for(status, period_months, previous_until)
        if status == 'pending'
          "Receipt for #{period_months} month(s) · payment pending"
        else
          default_payment_note(period_months, previous_until)
        end
      end

      def apply_subscription_adjustment!(user:, recorded_by:, active_until:, notes:, months: nil, amount: 0)
        payment = nil
        user.transaction do
          user.update!(subscription_active_until: active_until)
          payment = user.subscription_payments.create!(
            recorded_by: recorded_by,
            amount: amount,
            active_until: active_until,
            months: months,
            notes: notes,
            status: 'paid',
            paid_at: Time.current
          )
        end
        payment
      end

      def reduction_note(previous_until, new_until, months)
        parts = ["Reduced by #{months} month(s)"]
        parts << "from #{previous_until.strftime('%d %b %Y')}" if previous_until.present?
        parts << "to #{new_until.strftime('%d %b %Y')}"
        parts.join(' · ')
      end

      def notify_payment_recorded!(user, payment)
        Notification.notify!(
          user,
          title: 'Subscription payment received',
          body: "Your access is active until #{payment.active_until.strftime('%d %B %Y')}.",
          notification_type: 'success',
          link_path: '/dashboard'
        )
      end

      def reminder_cache_key(user, kind)
        "subscription_reminder:#{user.id}:#{kind}:#{Date.current}"
      end

      def reminder_sent_today?(user, kind)
        Rails.cache.exist?(reminder_cache_key(user, kind))
      end

      def mark_reminder_sent!(user, kind)
        Rails.cache.write(reminder_cache_key(user, kind), true, expires_in: 1.day)
      end

      def format_amount(amount)
        "Rs. #{format('%.2f', amount.to_f)}"
      end
    end
  end
end
