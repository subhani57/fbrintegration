# frozen_string_literal: true

module Invoices
  class ListScope
    def self.call(scope:, params:, admin: false, user: nil)
      new(scope: scope, params: params, admin: admin, user: user).call
    end

    def initialize(scope:, params:, admin: false, user: nil)
      @scope = scope
      @params = params
      @admin = admin
      @user = user
    end

    def call
      relation = portal_scope.order(invoice_date: :desc, created_at: :desc)

      relation = relation.where(status: @params[:status]) if @params[:status].present?
      relation = relation.where(user_id: @params[:user_id]) if @admin && @params[:user_id].present?
      relation = apply_date_range(relation)

      if @params[:q].present?
        q = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].strip)}%"
        relation = if @admin
                     relation.joins(:user).where(admin_search_sql, q: q)
                   else
                     relation.where(taxpayer_search_sql, q: q)
                   end
      end

      relation
    end

    private

    def portal_scope
      return @scope.excluding_sandbox_tests if @admin
      return @scope.for_user_environment(@user) if @user

      @scope.visible_in_production_portal
    end

    def apply_date_range(relation)
      start_date = parse_date(@params[:start_date])
      end_date = parse_date(@params[:end_date])
      return relation unless start_date || end_date

      if start_date && end_date
        relation.where(invoice_date: start_date..end_date)
      elsif start_date
        relation.where(invoice_date: start_date..)
      else
        relation.where(invoice_date: ..end_date)
      end
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def taxpayer_search_sql
      <<~SQL.squish
        invoices.invoice_number ILIKE :q
        OR invoices.pdf_invoice_number ILIKE :q
        OR invoices.buyer_name ILIKE :q
        OR invoices.buyer_ntn ILIKE :q
        OR invoices.fbr_invoice_id ILIKE :q
      SQL
    end

    def admin_search_sql
      <<~SQL.squish
        invoices.invoice_number ILIKE :q
        OR invoices.pdf_invoice_number ILIKE :q
        OR invoices.buyer_name ILIKE :q
        OR invoices.buyer_ntn ILIKE :q
        OR invoices.fbr_invoice_id ILIKE :q
        OR users.email ILIKE :q
        OR users.business_name ILIKE :q
      SQL
    end
  end
end
