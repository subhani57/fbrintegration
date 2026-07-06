# frozen_string_literal: true

module InvoiceExcelExportable
  extend ActiveSupport::Concern

  private

  def assign_export_dates
    @export_start_date = parse_export_date(params[:start_date]) || Date.current.beginning_of_month
    @export_end_date = parse_export_date(params[:end_date]) || Date.current
  end

  def parse_export_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def export_date_range_or_redirect(fallback_path)
    start_date = parse_export_date(params[:start_date])
    end_date = parse_export_date(params[:end_date])

    if start_date.blank? || end_date.blank?
      redirect_to fallback_path, alert: 'Please select a valid from and to date for export.'
      return
    end

    if start_date > end_date
      redirect_to fallback_path, alert: 'From date must be on or before to date.'
      return
    end

    [start_date, end_date]
  end

  def invoice_export_filename(prefix, start_date, end_date)
    "#{prefix}-#{start_date}-to-#{end_date}.xlsx"
  end
end
