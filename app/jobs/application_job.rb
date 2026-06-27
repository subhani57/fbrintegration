class ApplicationJob < ActiveJob::Base
  around_perform :log_job_execution, unless: -> { Rails.env.test? }

  private

  def log_job_execution
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    context = {
      job: self.class.name,
      job_id: job_id,
      queue: queue_name,
      arguments: arguments
    }

    AppLogger.info('job.started', **context)
    yield
    AppLogger.info('job.completed', duration_ms: AppLogger.elapsed_ms(start), **context)
  rescue StandardError => e
    AppLogger.error('job.failed', exception: e, duration_ms: AppLogger.elapsed_ms(start), **context)
    raise
  end
end
