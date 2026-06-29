# frozen_string_literal: true

class SubscriptionReminderJob < ApplicationJob
  queue_as :default

  def perform
    Subscriptions::Manager.remind_expiring_users!
  end
end
