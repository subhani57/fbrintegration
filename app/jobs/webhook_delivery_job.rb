# frozen_string_literal: true

class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform(webhook_id, event, payload)
    webhook = Webhook.find_by(id: webhook_id, active: true)
    return unless webhook

    body = { event: event, payload: payload, sent_at: Time.current.iso8601 }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', webhook.secret.to_s, body)

    HTTParty.post(
      webhook.url,
      body: body,
      headers: {
        'Content-Type' => 'application/json',
        'X-FBR-Event' => event,
        'X-FBR-Signature' => signature
      },
      timeout: 15
    )
  end
end
