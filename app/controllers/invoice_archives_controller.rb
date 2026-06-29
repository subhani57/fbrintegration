# frozen_string_literal: true

class InvoiceArchivesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_taxpayer_portal!

  def index
    @invoices = portal_user.invoices.where.not(fbr_invoice_id: [nil, '']).includes(:items).order(submitted_at: :desc)
    if params[:q].present?
      q = "%#{params[:q]}%"
      @invoices = @invoices.where('fbr_invoice_id ILIKE :q OR buyer_name ILIKE :q OR buyer_ntn ILIKE :q', q: q)
    end
    @invoices = @invoices.page(params[:page]).per(25)
  end

  def export
    ids = Array(params[:invoice_ids]).reject(&:blank?)
    if ids.empty?
      redirect_to invoice_archives_path, alert: 'Select at least one invoice to export.'
      return
    end

    invoices = portal_user.invoices.includes(:items).where(id: ids).where.not(fbr_invoice_id: nil)
    if invoices.empty?
      redirect_to invoice_archives_path, alert: 'No submitted invoices found for the selected rows.'
      return
    end

    zip_data = Invoices::BulkPdfExport.new(invoices).to_zip
    send_data zip_data,
              filename: "fbr-invoices-#{Date.current}.zip",
              type: 'application/zip',
              disposition: 'attachment'
  rescue StandardError => e
    AppLogger.error('invoice_archives.export_failed', exception: e, user_id: portal_user.id)
    redirect_to invoice_archives_path, alert: "Export failed: #{e.message}"
  end
end
