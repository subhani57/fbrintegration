class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer!
  before_action :load_fbr_configs, only: [:show, :edit, :update]

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params) && update_fbr_configs!
      redirect_to profile_path, notice: 'Business and FBR settings saved.'
    else
      flash.now[:alert] = [@user.errors.full_messages, @fbr_errors].flatten.compact.join(', ')
      render :edit, status: :unprocessable_entity
    end
  end

  def preferred_environment
    respond_to do |format|
      format.json { render json: { error: 'Contact your administrator to change the FBR submission environment.' }, status: :forbidden }
      format.turbo_stream { redirect_to profile_path, alert: 'Contact your administrator to change the FBR submission environment.' }
      format.html { redirect_to profile_path, alert: 'Contact your administrator to change the FBR submission environment.' }
    end
  end

  private

  def load_fbr_configs
    @configs_by_environment = FbrConfiguration.indexed_for_user(current_user)
  end

  def profile_params
    params.require(:user).permit(:ntn_cnic, :business_name, :address, :company_logo, :remove_company_logo, :seller_province)
  end

  def update_fbr_configs!
    @fbr_errors = []
    return true unless params[:fbr_configurations]

    params[:fbr_configurations].each do |environment, attrs|
      next unless FbrConfiguration::ENVIRONMENTS.include?(environment.to_s)

      config = @configs_by_environment[environment.to_s]
      token = attrs[:token].to_s.strip

      if config.taxpayer_token_locked?
        if token.present?
          @fbr_errors << "#{environment.to_s.humanize} FBR token cannot be changed after it is set. Contact your administrator."
        end
        next
      end

      next if token.blank?

      config.token = token
      config.active = true
      unless config.save
        @fbr_errors.concat(config.errors.full_messages)
      end
    end

    @fbr_errors.empty?
  end
end
