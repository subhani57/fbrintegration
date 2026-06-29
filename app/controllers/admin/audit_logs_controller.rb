# frozen_string_literal: true

module Admin
  class AuditLogsController < BaseController
    def index
      @logs = AuditLog.includes(:user).recent.page(params[:page]).per(50)
      @logs = @logs.where(action: params[:action_filter]) if params[:action_filter].present?
      @logs = @logs.where(user_id: params[:user_id]) if params[:user_id].present?
    end
  end
end
