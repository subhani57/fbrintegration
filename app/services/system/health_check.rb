# frozen_string_literal: true

module System
  class HealthCheck
    def self.report
      {
        database: database_ok?,
        redis: redis_ok?,
        sidekiq: sidekiq_stats,
        fbr_api: fbr_api_stats,
        subscriptions: Subscriptions::Manager.stats,
        checked_at: Time.current
      }
    end

    def self.database_ok?
      ActiveRecord::Base.connection.active?
    rescue StandardError
      false
    end

    def self.redis_ok?
      Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')).ping == 'PONG'
    rescue StandardError
      false
    end

    def self.sidekiq_stats
      return { available: false } unless defined?(Sidekiq)

      stats = Sidekiq::Stats.new
      { available: true, processed: stats.processed, failed: stats.failed, enqueued: stats.enqueued, busy: Sidekiq::Workers.new.size }
    rescue StandardError => e
      { available: false, error: e.message }
    end

    def self.fbr_api_stats
      recent = FbrLog.where('created_at >= ?', 24.hours.ago)
      total = recent.count
      errors = recent.where('status_code >= ?', 400).count
      { calls_24h: total, errors_24h: errors, success_rate: total.zero? ? 100 : (((total - errors) * 100.0) / total).round(1) }
    end
  end
end
