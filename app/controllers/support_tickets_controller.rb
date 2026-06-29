# frozen_string_literal: true

class SupportTicketsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ticket, only: [:show, :reply]

  def index
    @tickets = current_user.support_tickets.recent.page(params[:page]).per(20)
  end

  def new
    @ticket = current_user.support_tickets.new
  end

  def create
    @ticket = current_user.support_tickets.new(ticket_params)
    if @ticket.save
      redirect_to support_ticket_path(@ticket), notice: 'Support ticket submitted.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @replies = @ticket.replies.order(:created_at)
  end

  def reply
    @ticket.reply!(author: current_user, body: params[:body])
    redirect_to support_ticket_path(@ticket), notice: 'Reply added.'
  end

  private

  def set_ticket
    @ticket = current_user.support_tickets.find(params[:id])
  end

  def ticket_params
    params.require(:support_ticket).permit(:subject, :body, :priority)
  end
end
