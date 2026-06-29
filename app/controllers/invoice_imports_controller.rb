# frozen_string_literal: true

class InvoiceImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_taxpayer!

  def new
  end

  def template
    send_data Invoices::CsvTemplate.to_csv,
              filename: 'invoice_import_template.csv',
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end

  def create
    unless params[:file].present?
      redirect_to new_invoice_import_path, alert: 'Please select a CSV file.'
      return
    end

    results = Invoices::CsvImporter.new(portal_user, params[:file]).call
    success_count = results.count(&:success)
    errors = results.reject(&:success).flat_map(&:errors)

    if errors.any?
      redirect_to invoices_path, alert: "Imported #{success_count} invoice(s). Errors: #{errors.first(5).join('; ')}"
    else
      redirect_to invoices_path, notice: "Successfully imported #{success_count} invoice(s)."
    end
  end
end
