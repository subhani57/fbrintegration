module ApplicationHelper
  include BrandingHelper
  include ConfirmFormHelper

  def status_badge_color(status)
    invoice_status_badge_color(status, admin: false)
  end

  def admin_status_badge_color(status)
    invoice_status_badge_color(status, admin: true)
  end

  def invoice_status_badge_color(status, admin: false)
    case status&.to_s
    when 'draft'
      'secondary'
    when 'approved'
      'success'
    when 'validated', 'submitted'
      admin ? 'info' : 'success'
    when 'submitting', 'validating'
      'warning'
    when 'failed', 'rejected'
      'danger'
    when 'cancelled'
      admin ? 'danger' : 'dark'
    else
      'secondary'
    end
  end

  def format_pkr(amount, precision: 2)
    return 'Rs. 0.00' if amount.nil?

    value = number_with_precision(amount.to_f, precision: precision, delimiter: ',')
    "Rs. #{value}"
  end

  # Unit price may use up to 8 decimal places; trim trailing zeros, keep at least 2.
  def format_unit_price(amount)
    return 'Rs. 0.00' if amount.nil?

    int_part, frac_part = format('%.8f', amount.to_f).split('.', 2)
    frac_part = frac_part.to_s.sub(/0+\z/, '')
    frac_part = frac_part.ljust(2, '0')
    "Rs. #{number_with_delimiter(int_part)}.#{frac_part}"
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

  def invoice_fbr_environment_badge(invoice, fallback: nil)
    env = invoice.fbr_submission_environment.presence || fallback
    return tag.span('—', class: 'text-muted') if env.blank?

    css = env == 'production' ? 'danger' : 'success'
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

  def subscription_status_badge(user)
    return tag.span('—', class: 'text-muted') unless user.taxpayer?

    case user.subscription_status
    when :free_forever
      tag.span('Free forever', class: 'badge bg-info')
    when :active
      tag.span(user.subscription_active_until.strftime('%d %b %Y'), class: 'badge bg-success')
    when :expiring_soon
      tag.span("Expires in #{user.subscription_days_remaining}d", class: 'badge bg-warning text-dark')
    when :never_paid
      tag.span('Never paid', class: 'badge bg-secondary')
    else
      tag.span('Inactive', class: 'badge bg-danger')
    end
  end

  def subscription_days_left_display(user)
    return tag.span('—', class: 'text-muted') unless user.taxpayer?
    return tag.span('Unlimited', class: 'text-info fw-semibold') if user.subscription_free_forever?
    return tag.span('—', class: 'text-muted') if user.subscription_active_until.nil?

    if user.subscription_active?
      days = user.subscription_days_remaining
      css = days <= 10 ? 'text-danger fw-semibold' : 'text-success fw-semibold'
      tag.span("#{days} #{'day'.pluralize(days)}", class: css)
    else
      tag.span('0 days', class: 'text-danger fw-semibold')
    end
  end

  def auto_filter_form_options(html_class: nil)
    options = { data: { controller: 'auto-submit-form' } }
    options[:class] = html_class if html_class.present?
    options
  end

  def auto_filter_text_field_options
    { autocomplete: 'off', data: { action: 'input->auto-submit-form#submitDebounced' } }
  end

  def auto_filter_change_options
    { data: { action: 'change->auto-submit-form#submit' } }
  end
end
