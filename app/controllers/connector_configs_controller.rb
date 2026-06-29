# frozen_string_literal: true

class ConnectorConfigsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_taxpayer!
  before_action :set_connector, only: [:destroy, :test]

  def index
    @connectors = portal_user.connector_configs.order(:provider)
  end

  def create
    @connector = portal_user.connector_configs.new(connector_params)
    if @connector.save
      redirect_to connector_configs_path, notice: 'Connector saved.'
    else
      redirect_to connector_configs_path, alert: @connector.errors.full_messages.join(', ')
    end
  end

  def destroy
    @connector.destroy
    redirect_to connector_configs_path, notice: 'Connector removed.'
  end

  def test
    payload = JSON.parse(params[:payload].presence || '{}')
    invoice = @connector.ingest_payload!(payload)
    redirect_to invoice_path(invoice), notice: 'Test import created draft invoice.'
  rescue JSON::ParserError, StandardError => e
    redirect_to connector_configs_path, alert: "Test failed: #{e.message}"
  end

  private

  def set_connector
    @connector = portal_user.connector_configs.find(params[:id])
  end

  def connector_params
    params.require(:connector_config).permit(:name, :provider, :active, settings: {})
  end
end
