# frozen_string_literal: true

module Api
  module V2
    class BaseController < ActionController::API
      include ApiKeyAuthenticatable

      private

      def current_user
        current_api_user
      end
    end
  end
end
