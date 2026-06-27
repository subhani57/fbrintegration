# frozen_string_literal: true

module RequestLogging
  extend ActiveSupport::Concern

  included do
    before_action :store_request_log_start, unless: :skip_request_logging?
    after_action :log_request_completed, unless: :skip_request_logging?
  end

  private

  def skip_request_logging?
    Rails.env.test? || devise_controller?
  end

  def store_request_log_start
    @request_log_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    AppLogger.info('request.started', **request_log_context)
  end

  def log_request_completed
    AppLogger.info(
      'request.completed',
      duration_ms: AppLogger.elapsed_ms(@request_log_started_at),
      status: response.status,
      **request_log_context
    )
  end

  def request_log_context
    {
      request_id: request.request_id,
      method: request.request_method,
      path: request.fullpath,
      controller: controller_path,
      action: action_name,
      user_id: try(:current_user)&.id,
      format: request.format.ref
    }
  end
end
