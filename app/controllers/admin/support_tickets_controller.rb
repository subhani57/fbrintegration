# frozen_string_literal: true

module Admin
  class SupportTicketsController < BaseController
    before_action :set_ticket, only: [:show, :update, :reply]

    def index
      @tickets = SupportTicket.includes(:user).recent.page(params[:page]).per(30)
      @tickets = @tickets.where(status: params[:status]) if params[:status].present?
    end

    def show
      @replies = @ticket.replies.order(:created_at)
    end

    def update
      if @ticket.update(ticket_params)
        redirect_to admin_support_ticket_path(@ticket), notice: 'Ticket updated.'
      else
        redirect_to admin_support_ticket_path(@ticket), alert: @ticket.errors.full_messages.join(', ')
      end
    end

    def reply
      @ticket.reply!(author: current_user, body: params[:body], staff: true)
      @ticket.update!(status: 'resolved') if params[:resolve] == '1'
      Notification.notify!(@ticket.user, title: 'Support reply', body: 'An admin replied to your ticket.', notification_type: 'info', link_path: support_ticket_path(@ticket))
      redirect_to admin_support_ticket_path(@ticket), notice: 'Reply sent.'
    end

    private

    def set_ticket
      @ticket = SupportTicket.find(params[:id])
    end

    def ticket_params
      params.require(:support_ticket).permit(:status, :priority, :assigned_admin_id)
    end
  end
end
