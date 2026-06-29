# frozen_string_literal: true

module ApiKeyAuthenticatable
  extend ActiveSupport::Concern

  included do
    skip_before_action :verify_authenticity_token, raise: false
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    token = request.headers['Authorization'].to_s.remove(/^Bearer\s+/i).presence || params[:api_key]
    @api_key = ApiKey.authenticate(token)
    return if @api_key

    render json: { error: 'Invalid or missing API key' }, status: :unauthorized
  end

  def current_api_user
    @api_key&.user
  end
end
