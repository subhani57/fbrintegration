# frozen_string_literal: true

require 'csv'

module Reports
  class TaxSummary
    def self.for_user(user, start_date: nil, end_date: nil)
      start_date ||= Date.today.beginning_of_month
      end_date ||= Date.today.end_of_month
      base = user.invoices.for_user_environment(user).by_date_range(start_date, end_date)
      amounts = Invoices::AmountSummary.for(base)
      approved = amounts[:approved]
      failed_cancelled = amounts[:failed_cancelled]
      approved_scope = base.reporting_approved

      {
        period_label: "#{start_date.strftime('%d %b %Y')} – #{end_date.strftime('%d %b %Y')}",
        start_date: start_date,
        end_date: end_date,
        total_invoices: base.count,
        invoice_count: approved[:count],
        total_sales: approved[:total_amount],
        total_tax: approved[:tax_amount],
        net_amount: approved[:net_amount],
        total_amount: approved[:total_amount],
        approved: approved,
        failed_cancelled: failed_cancelled,
        by_status: base.group(:status).count,
        daily: approved_scope.group(:invoice_date).sum(:total_amount)
      }
    end

    def self.to_csv(summary)
      approved = summary[:approved] || {}
      failed_cancelled = summary[:failed_cancelled] || {}

      CSV.generate do |csv|
        csv << ['Period', summary[:period_label]]
        csv << []
        csv << ['Approved invoices', approved[:count]]
        csv << ['Approved net amount (PKR)', approved[:net_amount]]
        csv << ['Approved total incl. tax (PKR)', approved[:total_amount]]
        csv << ['Approved sales tax (PKR)', approved[:tax_amount]]
        csv << []
        csv << ['Failed / cancelled invoices', failed_cancelled[:count]]
        csv << ['Failed / cancelled total (PKR)', failed_cancelled[:total_amount]]
        csv << ['Failed / cancelled sales tax (PKR)', failed_cancelled[:tax_amount]]
        csv << []
        csv << ['Date', 'Approved sales (PKR)']
        summary[:daily].each { |date, amount| csv << [date, amount] }
      end
    end
  end
end
