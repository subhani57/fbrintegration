# frozen_string_literal: true

module Subscriptions
  class Manager
    EXPIRING_SOON_DAYS = 7
    TRIAL_DAYS = 7
    PERIOD_OPTIONS = {
      '1' => 1,
      '3' => 3,
      '6' => 6,
      '12' => 12
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
        return if user.subscription_payments.exists?

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

      def record_payment!(user:, active_until:, recorded_by:, amount: nil, notes: nil, period_months: nil)
        raise Error, 'Subscriptions apply to taxpayer accounts only.' unless user.taxpayer?
        raise Error, 'Active until date must be today or in the future.' if active_until < Date.current

        period_months ||= infer_period_months(user, active_until)
        amount ||= period_months * user.monthly_subscription_fee

        payment = nil
        user.transaction do
          previous_until = user.subscription_active_until
          user.update!(subscription_active_until: active_until)
          payment = user.subscription_payments.create!(
            recorded_by: recorded_by,
            amount: amount,
            active_until: active_until,
            notes: notes.presence || default_payment_note(period_months, previous_until)
          )
        end

        notify_payment_recorded!(user, payment)
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
          period_months: months
        )
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
          Notifications::SmsDelivery.deliver(user, "FBR Invoicing: subscription expires #{user.subscription_active_until.strftime('%d %b %Y')}.")
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

      private

      def extension_base_date(user)
        [user.subscription_active_until, Date.current].compact.max
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
