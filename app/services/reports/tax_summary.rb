# frozen_string_literal: true

require 'csv'

module Reports
  class TaxSummary
    def self.for_user(user, start_date: nil, end_date: nil)
      start_date ||= Date.today.beginning_of_month
      end_date ||= Date.today.end_of_month
      scope = user.invoices.by_date_range(start_date, end_date).where(fbr_status: 'submitted')

      {
        period_label: "#{start_date.strftime('%d %b %Y')} – #{end_date.strftime('%d %b %Y')}",
        start_date: start_date,
        end_date: end_date,
        invoice_count: scope.count,
        total_invoices: scope.count,
        total_sales: scope.sum(:total_amount).to_f,
        total_tax: scope.sum(:tax_amount).to_f,
        net_amount: scope.sum(:total_amount).to_f - scope.sum(:tax_amount).to_f,
        total_amount: scope.sum(:total_amount).to_f,
        by_status: user.invoices.by_date_range(start_date, end_date).group(:status).count,
        daily: scope.group(:invoice_date).sum(:total_amount)
      }
    end

    def self.to_csv(summary)
      CSV.generate do |csv|
        csv << ['Period', summary[:period_label]]
        csv << ['Invoices submitted', summary[:invoice_count]]
        csv << ['Total sales (PKR)', summary[:total_sales]]
        csv << ['Output tax (PKR)', summary[:total_tax]]
        csv << []
        csv << ['Date', 'Sales (PKR)']
        summary[:daily].each { |date, amount| csv << [date, amount] }
      end
    end
  end
end
