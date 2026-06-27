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
    environment = params[:environment].to_s
    unless FbrConfiguration::ENVIRONMENTS.include?(environment)
      respond_to do |format|
        format.json { render json: { error: 'Invalid environment.' }, status: :unprocessable_entity }
        format.html { redirect_to profile_path, alert: 'Invalid environment.' }
      end
      return
    end

    if (reason = Fbr::EnvironmentGuard.switch_environment_blocked_reason(current_user, environment))
      respond_to do |format|
        format.json { render json: { error: reason }, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: profile_path, alert: reason }
      end
      return
    end

    if current_user.update(preferred_fbr_environment: environment)
      notice = "#{environment.humanize} is now the active environment for invoice submission."
      respond_to do |format|
        format.json do
          render json: {
            environment: environment,
            notice: notice,
            banner_html: render_environment_banner_html
          }
        end
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_back fallback_location: profile_path, notice: notice }
      end
    else
      error = current_user.errors.full_messages.join(', ')
      respond_to do |format|
        format.json { render json: { error: error }, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: profile_path, alert: error }
      end
    end
  end

  private

  def load_fbr_configs
    @configs_by_environment = FbrConfiguration::ENVIRONMENTS.index_with do |environment|
      current_user.fbr_configurations.find_or_initialize_by(environment: environment) do |config|
        config.active = true
      end
    end
  end

  def render_environment_banner_html
    render_to_string(
      partial: 'shared/fbr_environment_banner',
      layout: false,
      formats: [:html]
    )
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
