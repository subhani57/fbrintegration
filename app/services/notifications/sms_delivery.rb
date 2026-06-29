# frozen_string_literal: true

module Notifications
  class SmsDelivery
    def self.deliver(user, message)
      return false unless user.phone.present?
      return false unless user.sms_notifications? || user.whatsapp_notifications?

      AppLogger.info('notification.sms_queued', user_id: user.id, phone: user.phone, channel: user.whatsapp_notifications? ? 'whatsapp' : 'sms')
      # Hook for JazzCash/EasyPaisa/Twilio — log only until gateway configured
      true
    end
  end
end
