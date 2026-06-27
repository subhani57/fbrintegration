# frozen_string_literal: true

class WebhooksController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer!
  before_action :set_webhook, only: [:edit, :update, :destroy]

  def index
    @webhooks = current_user.webhooks.order(:created_at)
  end

  def new
    @webhook = current_user.webhooks.new(events: %w[invoice.submitted invoice.failed])
  end

  def create
    @webhook = current_user.webhooks.new(webhook_params)
    if @webhook.save
      redirect_to webhooks_path, notice: 'Webhook created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @webhook.update(webhook_params)
      redirect_to webhooks_path, notice: 'Webhook updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook.destroy
    redirect_to webhooks_path, notice: 'Webhook removed.'
  end

  private

  def set_webhook
    @webhook = current_user.webhooks.find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(:url, :secret, :active, events: [])
  end
end
