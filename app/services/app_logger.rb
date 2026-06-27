# frozen_string_literal: true

class AppLogger
  LEVELS = %i[debug info warn error].freeze

  class << self
    def debug(message, **context)
      log(:debug, message, **context)
    end

    def info(message, **context)
      log(:info, message, **context)
    end

    def warn(message, **context)
      log(:warn, message, **context)
    end

    def error(message, exception: nil, **context)
      if exception
        context[:exception_class] = exception.class.name
        context[:exception_message] = exception.message
        context[:backtrace] = Array(exception.backtrace).first(10)
      end
      log(:error, message, **context)
    end

    def log(level, message, **context)
      level = level.to_sym
      level = :info unless LEVELS.include?(level)

      payload = {
        timestamp: Time.current.iso8601(3),
        level: level.to_s.upcase,
        message: message.to_s
      }.merge(compact_context(context))

      Rails.logger.public_send(level, payload.to_json)
    end

    def elapsed_ms(start_time)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(1)
    end

    private

    def compact_context(context)
      context.each_with_object({}) do |(key, value), result|
        next if value.nil?

        result[key] = value
      end
    end
  end
end
