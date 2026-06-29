# frozen_string_literal: true

module NavigationHelper
  def nav_controller?(*names)
    controller_name.in?(names.map(&:to_s))
  end

  def nav_path?(path)
    current_page?(path)
  end

  def nav_invoicing_active?
    nav_controller?(:invoices, :fbr_invoices, :invoice_archives, :recurring_invoices, :invoice_imports)
  end

  def nav_setup_active?
    nav_controller?(:companies, :profiles, :invoice_templates)
  end

  def nav_integrations_active?
    nav_controller?(:connector_configs, :webhooks, :api_keys)
  end

  def nav_reports_active?
    nav_controller?(:dashboard) && action_name == 'reports'
  end

  def nav_help_active?
    nav_controller?(:support_tickets, :notifications)
  end

  def nav_accountant_active?
    request.path.start_with?('/accountant')
  end

  def nav_admin_overview_active?
    nav_controller?(:dashboard) && controller_path == 'admin/dashboard'
  end

  def nav_admin_users_billing_active?
    nav_controller?(:users, :subscriptions, :subscription_plans, :accountant_clients)
  end

  def nav_admin_invoicing_active?
    nav_controller?(:invoices, :fbr_configurations)
  end

  def nav_admin_monitoring_active?
    nav_controller?(:reports, :fbr_logs, :audit_logs, :health)
  end

  def nav_admin_support_active?
    nav_controller?(:support_tickets)
  end

  def nav_dropdown_toggle(label, icon:, active: false)
    tag.button(
      type: 'button',
      class: "nav-link dropdown-toggle btn btn-link border-0 #{'active' if active}",
      data: {
        navbar_dropdown_target: 'button',
        action: 'click->navbar-dropdown#toggle'
      },
      aria: { expanded: 'false', haspopup: 'true' }
    ) do
      safe_join([tag.i(class: icon), ' ', label])
    end
  end

  def nav_dropdown_item(path, label, icon:, active: false, badge: nil)
    link_to(path, class: "dropdown-item #{'active' if active}") do
      parts = [tag.i(class: "#{icon} fa-fw me-2"), label]
      parts << tag.span(badge, class: 'badge bg-danger ms-2') if badge.present?
      safe_join(parts)
    end
  end

  def nav_dropdown_divider
    tag.div('', class: 'dropdown-divider')
  end

  def nav_dropdown_header(label)
    tag.h6(label, class: 'dropdown-header text-uppercase')
  end
end
