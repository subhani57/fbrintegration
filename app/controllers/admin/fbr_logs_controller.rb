# frozen_string_literal: true

module Admin
  class FbrLogsController < BaseController
    def index
      @logs = FbrLog.includes(:user, :invoice).recent.page(params[:page]).per(50)
      @logs = @logs.where(user_id: params[:user_id]) if params[:user_id].present?
      @logs = @logs.where(environment: params[:environment]) if params[:environment].present?
    end
  end
end
