# frozen_string_literal: true

module Webhooks
  class Dispatcher
    def self.dispatch(user, event, payload)
      user.webhooks.active.find_each do |webhook|
        next unless webhook.listens_to?(event)

        WebhookDeliveryJob.perform_later(webhook.id, event.to_s, payload.deep_stringify_keys)
      end
    end
  end
end
