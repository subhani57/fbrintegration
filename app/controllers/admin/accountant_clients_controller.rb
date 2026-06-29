# frozen_string_literal: true

module Admin
  class AccountantClientsController < BaseController
    def index
      @assignments = AccountantClient.includes(:accountant, :client).order(created_at: :desc).page(params[:page]).per(30)
    end

    def create
      assignment = AccountantClient.new(accountant_id: params[:accountant_id], client_id: params[:client_id])
      if assignment.save
        redirect_to admin_accountant_clients_path, notice: 'Accountant assigned to client.'
      else
        redirect_to admin_accountant_clients_path, alert: assignment.errors.full_messages.join(', ')
      end
    end

    def destroy
      AccountantClient.find(params[:id]).destroy
      redirect_to admin_accountant_clients_path, notice: 'Assignment removed.'
    end
  end
end
