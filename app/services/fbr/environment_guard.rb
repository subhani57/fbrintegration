# frozen_string_literal: true

module Fbr
  class EnvironmentGuard
    class Error < StandardError; end

    def self.production?(user)
      user.default_fbr_environment == 'production'
    end

    def self.sandbox?(user)
      !production?(user)
    end

    def self.token_configured?(user, environment)
      user.configuration_for(environment)&.token.present?
    end

    def self.business_profile_complete?(user)
      user.ntn_cnic.present? && user.business_name.present? && user.address.present?
    end

    def self.sandbox_test_invoice?(invoice)
      return false unless invoice

      invoice.test_data.is_a?(Hash) && invoice.test_data['sandbox_test'] == true
    end

    def self.switch_environment_blocked_reason(user, environment)
      env = environment.to_s
      return 'Invalid environment.' unless FbrConfiguration::ENVIRONMENTS.include?(env)
      return nil unless env == 'production'

      unless token_configured?(user, :production)
        return 'Configure your Production FBR token in Settings before switching to Production.'
      end

      unless business_profile_complete?(user)
        return 'Complete your business profile (NTN/CNIC, business name, address) before switching to Production.'
      end

      nil
    end

    def self.submission_blocked_reason(user, invoice: nil)
      env = user.default_fbr_environment

      unless token_configured?(user, env)
        label = env == 'production' ? 'Production' : 'Sandbox'
        return "#{label} FBR token is not configured. Add it in Settings."
      end

      if production?(user)
        unless business_profile_complete?(user)
          return 'Complete your business profile (NTN/CNIC, business name, address) before submitting to Production.'
        end

        if invoice && sandbox_test_invoice?(invoice)
          return 'Sandbox test invoices cannot be submitted to Production FBR.'
        end
      end

      nil
    end

    def self.sandbox_test_blocked_reason(user)
      if production?(user)
        return 'Test invoices cannot be sent while Production is the active FBR environment. Switch to Sandbox first.'
      end

      unless token_configured?(user, :sandbox)
        return 'Sandbox FBR token is not configured for this user.'
      end

      nil
    end

    def self.ensure_submission_allowed!(user, invoice: nil)
      reason = submission_blocked_reason(user, invoice: invoice)
      raise Error, reason if reason.present?
    end

    def self.ensure_environment_switch!(user, environment)
      reason = switch_environment_blocked_reason(user, environment)
      raise Error, reason if reason.present?
    end
  end
end
