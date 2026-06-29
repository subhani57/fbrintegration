# frozen_string_literal: true

module Admin
  class HealthController < BaseController
    def show
      @report = System::HealthCheck.report
    end
  end
end
