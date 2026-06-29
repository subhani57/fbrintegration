# frozen_string_literal: true

module Api
  module V2
    class InvoicesController < BaseController
      def index
        render json: current_user.invoices.includes(:items).order(created_at: :desc).limit(100).as_json(include: :items)
      end

      def show
        invoice = current_user.invoices.includes(:items).find(params[:id])
        render json: invoice.as_json(include: :items)
      end

      def create
        invoice = current_user.invoices.new(invoice_params)
        if invoice.save
          render json: invoice.as_json(include: :items), status: :created
        else
          render json: { errors: invoice.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def invoice_params
        params.require(:invoice).permit(
          :invoice_date, :invoice_type, :original_invoice_id,
          :buyer_ntn, :buyer_name, :buyer_province, :buyer_address,
          :buyer_registration_type, :buyer_company_id, :scenario_id,
          items_attributes: [:hs_code, :description, :quantity, :uom, :unit_price, :tax_rate, :sale_type]
        )
      end
    end
  end
end
