module ApplicationHelper
  include ConfirmFormHelper

  def status_badge_color(status)
    case status&.to_s
    when 'draft'
      'secondary'
    when 'validated', 'submitted', 'approved'
      'success'
    when 'submitting', 'validating'
      'warning'
    when 'failed', 'rejected'
      'danger'
    when 'cancelled'
      'dark'
    else
      'secondary'
    end
  end

  def format_pkr(amount)
    return 'Rs. 0.00' if amount.nil?

    value = number_with_precision(amount.to_f, precision: 2, delimiter: ',')
    "Rs. #{value}"
  end

  def invoice_fbr_submitted?(invoice)
    return false if invoice.cancelled? || invoice.fbr_status == 'cancelled'

    invoice.fbr_status == 'submitted' || invoice.fbr_invoice_id.present?
  end

  def invoice_net_amount(invoice)
    invoice.total_amount.to_f - invoice.tax_amount.to_f
  end

  def user_member_since(user)
    if user.respond_to?(:created_at) && user.created_at.present?
      user.created_at.to_date
    elsif user.respond_to?(:last_sign_in_at) && user.last_sign_in_at.present?
      user.last_sign_in_at.to_date
    else
      nil
    end
  end

  def fbr_environment_badge(environment)
    env = environment.to_s
    css = env == 'production' ? 'dark' : 'info'
    tag.span(env.humanize, class: "badge bg-#{css}")
  end

  def user_fbr_submission_environment(user)
    return unless user.respond_to?(:default_fbr_environment)

    user.default_fbr_environment
  end

  def user_fbr_submission_environment_display(user)
    env = user_fbr_submission_environment(user)
    return tag.span('—', class: 'text-muted') if env.blank?

    safe_join([
      fbr_environment_badge(env),
      tag.span('Current', class: 'badge bg-success ms-1')
    ])
  end

  def fbr_config_used_for_submissions?(configuration)
    user = configuration.user
    return false unless user

    user.default_fbr_environment == configuration.environment
  end

  def fbr_admin_token_status(config, compact: false)
    if config&.token_configured?
      if compact
        tag.span(class: 'badge bg-success-subtle text-success border border-success-subtle') do
          safe_join([tag.i(class: 'fas fa-check-circle me-1'), 'Ready'])
        end
      else
        tag.span(class: 'badge bg-success') do
          safe_join([tag.i(class: 'fas fa-check-circle me-1'), 'Configured'])
        end
      end
    elsif compact
      tag.span(class: 'badge bg-light text-muted border') do
        safe_join([tag.i(class: 'fas fa-minus-circle me-1'), 'Not set'])
      end
    else
      tag.span('Not set', class: 'text-muted')
    end
  end

  def fbr_admin_environment_cell(user, environment, config)
    active = user.default_fbr_environment == environment
    safe_join([
      fbr_admin_token_status(config, compact: true),
      (tag.span('Active', class: 'badge bg-primary ms-1') if active)
    ].compact, ' ')
  end

  def production_fbr_active?
    user_signed_in? && current_user.taxpayer? && Fbr::EnvironmentGuard.production?(current_user)
  end

  def fbr_submission_blocked_reason(user = current_user, invoice: nil)
    return nil unless user&.taxpayer?

    Fbr::EnvironmentGuard.submission_blocked_reason(user, invoice: invoice)
  end

  def fbr_submission_confirm(action, user = current_user)
    env = user.default_fbr_environment.humanize
    if Fbr::EnvironmentGuard.production?(user)
      "This will #{action} a LIVE invoice to FBR Production. This cannot be undone. Continue?"
    else
      "Validate this invoice with FBR #{env}?"
    end
  end

  def fbr_submit_confirm(user = current_user)
    if Fbr::EnvironmentGuard.production?(user)
      'Submit this invoice to FBR Production? This is a live submission and cannot be undone.'
    else
      'Submit this invoice to FBR Sandbox?'
    end
  end
end
