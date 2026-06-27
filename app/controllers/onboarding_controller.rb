# frozen_string_literal: true

class OnboardingController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :ensure_approved_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer!

  def show
    @step = current_user.onboarding_step
    @profile_complete = Fbr::EnvironmentGuard.business_profile_complete?(current_user)
    @token_configured = Fbr::EnvironmentGuard.token_configured?(current_user, current_user.default_fbr_environment)
  end

  def update
    case params[:step].to_i
    when 1
      if current_user.update(profile_params)
        current_user.advance_onboarding! if current_user.onboarding_step < 1
        redirect_to onboarding_path, notice: 'Business profile saved.'
      else
        @step = 0
        render :show, status: :unprocessable_entity
      end
    when 2
      config = current_user.configuration_for('sandbox') || current_user.fbr_configurations.build(environment: 'sandbox')
      config.token = params.dig(:fbr_configuration, :token)
      if config.save
        current_user.advance_onboarding! if current_user.onboarding_step < 2
        redirect_to onboarding_path, notice: 'Sandbox FBR token saved.'
      else
        @step = 1
        render :show, status: :unprocessable_entity
      end
    when 3
      current_user.advance_onboarding!
      redirect_to invoices_path, notice: 'Setup complete. Create your first invoice!'
    else
      redirect_to onboarding_path
    end
  end

  def skip
    current_user.update!(onboarding_step: 3)
    redirect_to invoices_path
  end

  private

  def profile_params
    params.require(:user).permit(:business_name, :ntn_cnic, :address, :seller_province)
  end
end
