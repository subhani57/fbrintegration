# frozen_string_literal: true

module Invoices
  class AmountSummary
    APPROVED_STATUSES = %w[approved submitted].freeze
    FAILED_CANCELLED_STATUSES = %w[failed cancelled rejected].freeze

    def self.for(scope)
      new(scope).call
    end

    def initialize(scope)
      @scope = scope
    end

    def call
      {
        approved: totals_for(@scope.reporting_approved),
        failed_cancelled: totals_for(@scope.reporting_failed_or_cancelled)
      }
    end

    private

    def totals_for(relation)
      total = relation.sum(:total_amount).to_f
      tax = relation.sum(:tax_amount).to_f

      {
        count: relation.count,
        total_amount: total,
        tax_amount: tax,
        net_amount: total - tax
      }
    end
  end
end
