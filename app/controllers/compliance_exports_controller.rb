# frozen_string_literal: true

class ComplianceExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_taxpayer_portal!

  def create
    start_date = Date.parse(params[:start_date].to_s)
    end_date = Date.parse(params[:end_date].to_s)
    csv = Compliance::Exporter.new(portal_user, start_date: start_date, end_date: end_date).to_csv
    send_data csv, filename: "compliance-#{start_date}-#{end_date}.csv", type: 'text/csv'
  rescue ArgumentError
    redirect_back fallback_location: reports_path, alert: 'Invalid date range.'
  end
end
