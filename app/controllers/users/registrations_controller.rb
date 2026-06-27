module Users
  class RegistrationsController < Devise::RegistrationsController
    layout 'auth'

    before_action :configure_permitted_parameters, if: :devise_controller?

    protected

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[ntn_cnic business_name address])
    end

    def build_resource(hash = {})
      super(hash.merge(role: 'taxpayer', approved: false, onboarding_step: 0))
    end
  end
end
