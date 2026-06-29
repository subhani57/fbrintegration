# frozen_string_literal: true

module Accountant
  class DashboardController < ApplicationController
    include ManagedClientContext

    before_action :authenticate_user!
    before_action :require_accountant!

    def index
      @clients = current_user.clients.order(:email)
      @active_client = portal_user if managed_client?
    end

    def switch
      client = current_user.clients.find(params[:client_id])
      session[:managed_client_id] = client.id
      redirect_to dashboard_path, notice: "Now managing #{client.email}."
    end

    def clear
      session.delete(:managed_client_id)
      redirect_to accountant_dashboard_path, notice: 'Switched back to accountant view.'
    end
  end
end
