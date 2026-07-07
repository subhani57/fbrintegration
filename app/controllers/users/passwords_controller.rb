module Users
  class PasswordsController < Devise::PasswordsController
    layout 'auth'

    def create
      unless MailerConfig.smtp_configured?
        redirect_to new_user_password_path, alert: MailerConfig.delivery_error_message
        return
      end

      super
    rescue StandardError => e
      raise unless mail_delivery_error?(e)

      AppLogger.error('auth.password_reset_email_failed', exception: e)
      redirect_to new_user_password_path, alert: MailerConfig.delivery_error_message
    end

    private

    def mail_delivery_error?(error)
      error.is_a?(Errno::ECONNREFUSED) ||
        error.is_a?(SocketError) ||
        error.class.name.start_with?("Net::SMTP")
    end
  end
end
