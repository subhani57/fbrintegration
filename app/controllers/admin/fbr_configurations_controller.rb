module Admin
  class FbrConfigurationsController < BaseController
    before_action :set_user, only: [:edit, :update]

    def index
      @stats = index_stats
      @users = filtered_taxpayers.page(params[:page]).per(30)
    end

    def edit
      load_configs_by_environment
    end

    def update
      load_configs_by_environment

      if update_fbr_configs!
        redirect_to admin_fbr_configurations_path, notice: "FBR settings saved for #{@user.email}."
      else
        flash.now[:alert] = @fbr_errors.join(", ") if @fbr_errors.present?
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def filtered_taxpayers
      scope = User.taxpayers.includes(:fbr_configurations).order(:email)

      if params[:q].present?
        term = "%#{User.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.where("email ILIKE :term OR business_name ILIKE :term", term: term)
      end

      case params[:token]
      when "missing_sandbox"
        scope = scope.where.not(id: FbrConfiguration.sandbox.with_token.select(:user_id))
      when "missing_production"
        scope = scope.where.not(id: FbrConfiguration.production.with_token.select(:user_id))
      when "complete"
        scope = scope.where(id: FbrConfiguration.sandbox.with_token.select(:user_id))
                       .where(id: FbrConfiguration.production.with_token.select(:user_id))
      when "missing_any"
        complete_ids = User.taxpayers
          .where(id: FbrConfiguration.sandbox.with_token.select(:user_id))
          .where(id: FbrConfiguration.production.with_token.select(:user_id))
          .select(:id)
        scope = scope.where.not(id: complete_ids)
      end

      scope
    end

    def index_stats
      taxpayer_ids = User.taxpayers.select(:id)
      sandbox_ready = FbrConfiguration.sandbox.with_token.where(user_id: taxpayer_ids).distinct.count(:user_id)
      production_ready = FbrConfiguration.production.with_token.where(user_id: taxpayer_ids).distinct.count(:user_id)
      total = User.taxpayers.count

      {
        total: total,
        sandbox_ready: sandbox_ready,
        production_ready: production_ready,
        fully_ready: User.taxpayers
          .where(id: FbrConfiguration.sandbox.with_token.select(:user_id))
          .where(id: FbrConfiguration.production.with_token.select(:user_id))
          .count
      }
    end

    def set_user
      @user = User.taxpayers.find(params[:id])
    end

    def load_configs_by_environment
      @configs_by_environment = FbrConfiguration::ENVIRONMENTS.index_with do |environment|
        @user.fbr_configurations.find_or_initialize_by(environment: environment) do |config|
          config.active = true
        end
      end
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
end
