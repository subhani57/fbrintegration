# frozen_string_literal: true

module Fbr
  module JobRunner
    module_function

    def enqueue(job_class, *args)
      if inline?
        job_class.perform_now(*args)
      else
        job_class.perform_later(*args)
      end
    end

    def inline?
      return true if ActiveModel::Type::Boolean.new.cast(ENV['INLINE_FBR_JOBS'])
      return true if Rails.application.config.active_job.queue_adapter == :inline

      false
    end
  end
end
