# frozen_string_literal: true

module Api
  module V1
    class InvoicesController < Api::BaseController
      before_action :set_invoice, only: [:show, :submit, :validate]

      def index
        invoices = current_user.invoices.order(created_at: :desc).limit(100)
        render json: invoices.as_json(include: :items)
      end

      def show
        render json: @invoice.as_json(include: :items)
      end

      def create
        invoice = current_user.invoices.new(invoice_api_params)
        if invoice.save
          render json: invoice.as_json(include: :items), status: :created
        else
          render json: { errors: invoice.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def submit
        unless @invoice.draft? || @invoice.validated? || @invoice.failed?
          return render json: { error: 'Invalid state for submission' }, status: :unprocessable_entity
        end

        @invoice.submit_to_fbr! if @invoice.may_submit_to_fbr?
        render json: { message: 'Submission queued', invoice_id: @invoice.id, status: @invoice.status }
      end

      def validate
        @invoice.validate_invoice! if @invoice.may_validate_invoice?
        render json: { message: 'Validation queued', invoice_id: @invoice.id, status: @invoice.status }
      rescue AASM::InvalidTransition
        service = Fbr::ApiService.new(current_user, current_user.default_fbr_environment.to_sym)
        result = service.validate_invoice(@invoice)
        render json: result
      end

      private

      def set_invoice
        @invoice = current_user.invoices.find(params[:id])
      end

      def invoice_api_params
        params.require(:invoice).permit(
          :invoice_date, :invoice_type, :original_invoice_id,
          :buyer_ntn, :buyer_name, :buyer_province, :buyer_address,
          :buyer_registration_type, :buyer_company_id, :scenario_id,
          items_attributes: [:hs_code, :description, :quantity, :uom, :unit_price, :tax_rate, :sale_type, :sro_schedule_no]
        )
      end
    end
  end
end
