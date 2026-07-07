# frozen_string_literal: true

require 'fileutils'

module Users
  class Clone
    USER_COPY_COLUMNS = %w[
      role approved business_name address ntn_cnic phone seller_province
      preferred_fbr_environment onboarding_step subscription_active_until
      subscription_free_forever subscription_plan_id sms_notifications
      whatsapp_notifications
    ].freeze

    SKIP_INVOICE_FBR_IDS = ActiveModel::Type::Boolean.new.cast(
      ENV.fetch('CLONE_SKIP_FBR_IDS', 'false')
    )

    class Error < StandardError; end

    def self.call(source_email:, target_email:, password: nil, replace_target: false)
      new(
        source_email: source_email,
        target_email: target_email,
        password: password,
        replace_target: replace_target
      ).call
    end

    def initialize(source_email:, target_email:, password: nil, replace_target: false)
      @source_email = source_email.to_s.strip.downcase
      @target_email = target_email.to_s.strip.downcase
      @password = password.presence || SecureRandom.hex(12)
      @replace_target = replace_target
    end

    def call
      source = User.find_by('LOWER(email) = ?', @source_email)
      raise Error, "Source user not found: #{@source_email}" unless source

      summary = {}
      target = nil

      User.transaction do
        target = prepare_target_user!(source)
        summary.merge!(clone_associations!(source, target))
      end

      {
        source: source,
        target: target.reload,
        password: @password,
        summary: summary
      }
    end

    private

    def prepare_target_user!(source)
      existing = User.find_by('LOWER(email) = ?', @target_email)
      if existing
        raise Error, "Target #{@target_email} already exists. Set REPLACE_TARGET=true to replace." unless @replace_target

        existing.destroy!
      end

      target = User.new(source.attributes.slice(*USER_COPY_COLUMNS))
      target.email = @target_email
      target.password = @password
      target.password_confirmation = @password
      target.allow_sandbox_environment = source.preferred_fbr_environment == 'sandbox'
      target.assign_attributes(devise_reset_attributes)

      User.skip_callback(:create, :after, :create_default_configuration)
      target.save!
      User.set_callback(:create, :after, :create_default_configuration)

      copy_company_logo!(source, target)
      target
    end

    def devise_reset_attributes
      {
        reset_password_token: nil,
        reset_password_sent_at: nil,
        remember_created_at: nil,
        confirmation_token: nil,
        confirmation_sent_at: nil,
        confirmed_at: Time.current,
        unconfirmed_email: nil,
        unlock_token: nil,
        locked_at: nil,
        failed_attempts: 0,
        sign_in_count: 0,
        current_sign_in_at: nil,
        last_sign_in_at: nil,
        current_sign_in_ip: nil,
        last_sign_in_ip: nil
      }
    end

    def clone_associations!(source, target)
      company_map = clone_companies!(source, target)
      template_map = clone_invoice_templates!(source, target, company_map)
      invoice_map = clone_invoices!(source, target, company_map)
      remap_original_invoices!(source, target, invoice_map)

      {
        companies: company_map.size,
        invoice_templates: template_map.size,
        invoices: invoice_map.size,
        invoice_items: InvoiceItem.where(invoice_id: invoice_map.values).count,
        fbr_configurations: clone_fbr_configurations!(source, target),
        fbr_logs: clone_fbr_logs!(source, target, invoice_map),
        notifications: clone_records!(source.notifications, target),
        webhooks: clone_records!(source.webhooks, target),
        connector_configs: clone_records!(source.connector_configs, target),
        buyer_verification_caches: clone_records!(BuyerVerificationCache.where(user_id: source.id), target),
        subscription_payments: clone_subscription_payments!(source, target),
        support_tickets: clone_support_tickets!(source, target),
        recurring_invoices: clone_recurring_invoices!(source, target, company_map, template_map),
        accountant_clients: clone_accountant_links!(source, target)
      }
    end

    def clone_companies!(source, target)
      map = {}
      source.companies.find_each do |company|
        copy = company.dup
        copy.user = target
        copy.save!
        map[company.id] = copy.id
      end
      map
    end

    def clone_invoice_templates!(source, target, company_map)
      map = {}
      source.invoice_templates.find_each do |template|
        copy = template.dup
        copy.user = target
        copy.buyer_company_id = company_map[template.buyer_company_id]
        copy.save!
        map[template.id] = copy.id
      end
      map
    end

    def clone_invoices!(source, target, company_map)
      map = {}
      source.invoices.includes(:items).find_each do |invoice|
        copy = invoice.dup
        copy.user = target
        copy.buyer_company_id = company_map[invoice.buyer_company_id]
        copy.original_invoice_id = nil
        clear_fbr_identifiers!(copy) if SKIP_INVOICE_FBR_IDS
        copy.save!

        invoice.items.each do |item|
          item_copy = item.dup
          item_copy.invoice = copy
          item_copy.save!
        end

        map[invoice.id] = copy.id
      end
      map
    end

    def remap_original_invoices!(source, _target, invoice_map)
      source.invoices.where.not(original_invoice_id: nil).find_each do |invoice|
        new_id = invoice_map[invoice.id]
        new_original_id = invoice_map[invoice.original_invoice_id]
        next unless new_id && new_original_id

        Invoice.where(id: new_id).update_all(original_invoice_id: new_original_id)
      end
    end

    def clone_fbr_configurations!(source, target)
      target.fbr_configurations.delete_all
      count = 0
      source.fbr_configurations.find_each do |config|
        copy = config.dup
        copy.user = target
        copy.save!(validate: false)
        count += 1
      end
      count
    end

    def clone_fbr_logs!(source, target, invoice_map)
      count = 0
      source.fbr_logs.find_each do |log|
        copy = log.dup
        copy.user = target
        copy.invoice_id = invoice_map[log.invoice_id]
        copy.save!
        count += 1
      end
      count
    end

    def clone_subscription_payments!(source, target)
      count = 0
      source.subscription_payments.find_each do |payment|
        copy = payment.dup
        copy.user = target
        copy.receipt_number = nil
        copy.save!
        count += 1
      end
      count
    end

    def clone_support_tickets!(source, target)
      count = 0
      source.support_tickets.includes(:replies).find_each do |ticket|
        copy = ticket.dup
        copy.user = target
        copy.assigned_admin_id = ticket.assigned_admin_id
        copy.save!

        ticket.replies.each do |reply|
          reply_copy = reply.dup
          reply_copy.support_ticket = copy
          reply_copy.user = reply.staff_reply ? reply.user : target
          reply_copy.save!
        end
        count += 1
      end
      count
    end

    def clone_recurring_invoices!(source, target, company_map, template_map)
      count = 0
      source.recurring_invoices.find_each do |recurring|
        copy = recurring.dup
        copy.user = target
        copy.buyer_company_id = company_map[recurring.buyer_company_id]
        copy.invoice_template_id = template_map[recurring.invoice_template_id]
        copy.save!
        count += 1
      end
      count
    end

    def clone_accountant_links!(source, target)
      count = 0
      source.accountant_clients.find_each do |link|
        next if AccountantClient.exists?(accountant_id: target.id, client_id: link.client_id)

        copy = link.dup
        copy.accountant = target
        copy.save!
        count += 1
      end

      source.accountant_assignments.find_each do |link|
        next if AccountantClient.exists?(accountant_id: link.accountant_id, client_id: target.id)

        copy = link.dup
        copy.client = target
        copy.save!
        count += 1
      end
      count
    end

    def clone_records!(scope, target)
      count = 0
      scope.find_each do |record|
        copy = record.dup
        copy.user = target
        copy.save!
        count += 1
      end
      count
    end

    def clear_fbr_identifiers!(invoice)
      invoice.fbr_invoice_id = nil
      invoice.fbr_status = nil
      invoice.submitted_at = nil
      invoice.status = 'draft' if invoice.status.in?(%w[submitted approved submitting validating])
    end

    def copy_company_logo!(source, target)
      return unless source.company_logo.present?

      path = source.company_logo.path
      return unless path && File.exist?(path)

      FileUtils.mkdir_p(File.dirname(target.company_logo.path))
      FileUtils.cp(path, target.company_logo.path)

      if source.company_logo.thumb.path && File.exist?(source.company_logo.thumb.path)
        FileUtils.mkdir_p(File.dirname(target.company_logo.thumb.path))
        FileUtils.cp(source.company_logo.thumb.path, target.company_logo.thumb.path)
      end

      target.update_column(:company_logo, target.company_logo.identifier)
    rescue StandardError => e
      AppLogger.warn('users.clone.company_logo_failed', exception: e, source_id: source.id, target_id: target.id)
    end
  end
end
