module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy, :send_test_fbr_invoices, :preferred_fbr_environment, :approve]

    def index
      @users = User.where.not(role: 'admin').order(:email).page(params[:page]).per(30)

      if params[:role].present? && User::ROLES.include?(params[:role]) && params[:role] != 'admin'
        @users = @users.where(role: params[:role])
      end
    end

    def new
      @user = User.new(role: 'taxpayer', approved: true)
    end

    def create
      @user = User.new(user_params)
      generated_password = SecureRandom.hex(12)
      @user.password = generated_password
      @user.password_confirmation = generated_password

      if @user.save
        redirect_to admin_user_path(@user),
                    notice: "User created. Temporary password: #{generated_password} (share securely and ask user to change it)."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @invoices = @user.invoices.order(created_at: :desc).limit(10)
      @sandbox_config = @user.fbr_configurations.find { |c| c.environment == 'sandbox' }
      if @user.taxpayer?
        @completed_sandbox_scenarios = Fbr::SandboxTestInvoicesService.completed_scenario_ids_for(@user)
        @pending_sandbox_scenarios = Fbr::SandboxTestInvoicesService::SCENARIO_IDS - @completed_sandbox_scenarios
        @sandbox_test_blocked_reason = Fbr::SandboxTestInvoicesService.blocked_reason_for(@user)
      end
    end

    def edit
    end

    def update
      if @user == current_user && user_params[:role].present? && user_params[:role] != @user.role
        redirect_to edit_admin_user_path(@user), alert: 'You cannot change your own role.'
        return
      end

      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: 'User updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: 'You cannot delete your own account.'
        return
      end

      @user.destroy
      redirect_to admin_users_path, notice: 'User removed.'
    end

    def send_test_fbr_invoices
      unless @user.taxpayer?
        redirect_to admin_user_path(@user), alert: 'Test invoices can only be sent for taxpayer accounts.'
        return
      end

      if (blocked_reason = Fbr::SandboxTestInvoicesService.blocked_reason_for(@user))
        redirect_to admin_user_path(@user), alert: blocked_reason
        return
      end

      results = Fbr::SandboxTestInvoicesService.new(@user).call
      submitted = results.count { |r| r.success && !r.skipped? }
      skipped = results.count(&:skipped?)
      failures = results.count { |r| !r.success && !r.skipped? }

      details = results.map do |r|
        if r.skipped?
          "↷ #{r.scenario_id} (already sent)"
        elsif r.success
          "✓ #{r.scenario_id}"
        else
          "✗ #{r.scenario_id}: #{r.error_message}"
        end
      end.join(' · ')

      if failures.zero? && submitted.zero? && skipped.positive?
        redirect_to admin_user_path(@user),
                    notice: "All #{skipped} sandbox scenario(s) were already submitted to FBR. #{details}"
      elsif failures.zero?
        redirect_to admin_user_path(@user),
                    notice: "Sent #{submitted} sandbox test invoice(s) to FBR#{" (#{skipped} skipped)" if skipped.positive?}. #{details}"
      else
        redirect_to admin_user_path(@user),
                    alert: "#{submitted} sent, #{skipped} skipped, #{failures} failed. #{details}"
      end
    rescue Fbr::SandboxTestInvoicesService::ProductionEnvironmentError => e
      redirect_to admin_user_path(@user), alert: e.message
    rescue Fbr::SandboxTestInvoicesService::AlreadyRunningError => e
      redirect_to admin_user_path(@user), alert: e.message
    rescue StandardError => e
      redirect_to admin_user_path(@user), alert: "Sandbox test failed: #{e.message}"
    end

    def preferred_fbr_environment
      unless @user.taxpayer?
        redirect_to admin_user_path(@user), alert: 'Only taxpayer accounts have a submission environment.'
        return
      end

      environment = params[:environment].to_s
      unless FbrConfiguration::ENVIRONMENTS.include?(environment)
        redirect_to admin_user_path(@user), alert: 'Invalid environment.'
        return
      end

      if (reason = Fbr::EnvironmentGuard.switch_environment_blocked_reason(@user, environment))
        redirect_to admin_user_path(@user), alert: reason
        return
      end

      if @user.update(preferred_fbr_environment: environment)
        redirect_to admin_user_path(@user),
                    notice: "#{environment.humanize} is now the active environment for this user's submissions."
      else
        redirect_to admin_user_path(@user), alert: @user.errors.full_messages.join(', ')
      end
    end

    def approve
      if @user.update(approved: true)
        trial_notice = grant_approval_trial_if_eligible
        UserMailer.account_approved(@user).deliver_later
        AuditLog.record!(user: current_user, action: 'user.approved', auditable: @user, request: request)
        redirect_to admin_user_path(@user), notice: ['User account approved.', trial_notice].compact.join(' ')
      else
        redirect_to admin_user_path(@user), alert: @user.errors.full_messages.join(', ')
      end
    end

    private

    def set_user
      @user = User.includes(:fbr_configurations).find(params[:id])
    end

    def grant_approval_trial_if_eligible
      return unless @user.taxpayer?
      return unless @user.subscription_never_paid?

      Subscriptions::Manager.grant_trial!(@user, recorded_by: current_user)
      " #{Subscriptions::Manager::TRIAL_DAYS}-day trial access granted."
    end

    def user_params
      params.require(:user).permit(:email, :role, :ntn_cnic, :business_name, :address, :preferred_fbr_environment, :approved, :seller_province)
    end
  end
end
