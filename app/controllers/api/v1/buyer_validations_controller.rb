# frozen_string_literal: true

module Api
  module V1
    class BuyerValidationsController < Api::BaseController
      def create
        ntn = params[:ntn].to_s.strip
        return render json: { error: 'NTN is required' }, status: :unprocessable_entity if ntn.blank?

        result = Fbr::BuyerVerificationService.new(current_user).verify(ntn)

        if result[:success]
          render json: {
            ntn: result[:registration_no],
            registration_type: result[:registration_type],
            registered: result[:registered],
            atl_status: result[:atl_status],
            atl_active: result[:atl_active],
            registration: result[:get_reg_type],
            statl: result[:statl],
            message: verification_message(result)
          }
        else
          render json: {
            error: result[:error] || 'Could not verify buyer registration with FBR.',
            details: result
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Buyer validation error: #{e.message}"
        render json: { error: 'Buyer verification failed. Try again later.' }, status: :internal_server_error
      end

      private

      def verification_message(result)
        parts = ["FBR: #{result[:registration_type]}"]
        parts << "ATL #{result[:atl_status]}" if result[:atl_status].present?
        parts.join(' · ')
      end
    end
  end
end
