# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_taxpayer!
  before_action :set_api_key, only: [:destroy]

  def index
    @api_keys = current_user.api_keys.order(created_at: :desc)
  end

  def create
    @api_key = current_user.api_keys.new(name: params[:name].presence || 'API Key')
    if @api_key.save
      flash[:api_key_token] = @api_key.plain_token
      redirect_to api_keys_path, notice: 'API key created. Copy it now — it will not be shown again.'
    else
      redirect_to api_keys_path, alert: @api_key.errors.full_messages.join(', ')
    end
  end

  def destroy
    @api_key.revoke!
    redirect_to api_keys_path, notice: 'API key revoked.'
  end

  private

  def set_api_key
    @api_key = current_user.api_keys.find(params[:id])
  end
end
