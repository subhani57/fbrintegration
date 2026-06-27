# frozen_string_literal: true

module Fbr
  class SandboxTestInvoicesService
    SCENARIO_IDS = %w[SN001 SN002 SN005 SN006 SN007 SN008].freeze
    LINE_VALUE = 1.0

    Result = Struct.new(:scenario_id, :name, :success, :fbr_invoice_id, :error_message, :invoice, :skipped, keyword_init: true) do
      def skipped?
        skipped == true
      end
    end

    class AlreadyRunningError < StandardError; end
    class ProductionEnvironmentError < StandardError; end

    def self.allowed_for?(user)
      blocked_reason_for(user).nil?
    end

    def self.blocked_reason_for(user)
      Fbr::EnvironmentGuard.sandbox_test_blocked_reason(user)
    end

    def self.completed_scenario_ids_for(user)
      sandbox_test_invoices_for(user).distinct.pluck(:scenario_id)
    end

    def self.sandbox_test_invoices_for(user)
      user.invoices
        .where(scenario_id: SCENARIO_IDS)
        .where(fbr_status: 'submitted')
        .where.not(fbr_invoice_id: [nil, ''])
        .where("test_data->>'sandbox_test' = ?", 'true')
    end

    def initialize(user)
      @user = user
    end

    def call
      validate_sandbox_token!

      with_submission_lock do
        scenario_specs.map do |spec|
          submit_scenario(spec)
        end
      end
    end

    private

    attr_reader :user

    def validate_sandbox_token!
      reason = self.class.blocked_reason_for(user)
      return if reason.blank?

      raise ProductionEnvironmentError, reason if user.default_fbr_environment == 'production'

      raise reason
    end

    def submit_scenario(spec)
      if (existing = existing_sandbox_submission(spec[:scenario_id]))
        return Result.new(
          scenario_id: spec[:scenario_id],
          name: spec[:name],
          success: true,
          skipped: true,
          fbr_invoice_id: existing.fbr_invoice_id,
          error_message: nil,
          invoice: existing
        )
      end

      payload = build_payload(spec)
      response = api_service.submit_invoice_payload(payload)
      invoice = persist_invoice(spec, payload, response)

      Result.new(
        scenario_id: spec[:scenario_id],
        name: spec[:name],
        success: response[:success],
        fbr_invoice_id: response[:fbr_invoice_id],
        error_message: response[:error_message],
        invoice: invoice,
        skipped: false
      )
    rescue StandardError => e
      Result.new(
        scenario_id: spec[:scenario_id],
        name: spec[:name],
        success: false,
        error_message: e.message,
        invoice: nil,
        skipped: false
      )
    end

    def with_submission_lock
      key = "fbr:sandbox_test_invoices:#{user.id}"
      raise AlreadyRunningError, 'Sandbox test invoices are already being sent. Please wait.' if Rails.cache.read(key)

      Rails.cache.write(key, true, expires_in: 10.minutes)
      yield
    ensure
      Rails.cache.delete(key)
    end

    def existing_sandbox_submission(scenario_id)
      self.class.sandbox_test_invoices_for(user)
        .where(scenario_id: scenario_id)
        .order(submitted_at: :desc)
        .first
    end

    def api_service
      @api_service ||= Fbr::ApiService.new(user, :sandbox)
    end

    def build_payload(spec)
      {
        invoiceType: 'Sale Invoice',
        invoiceDate: Date.today.strftime('%Y-%m-%d'),
        sellerNTNCNIC: user.ntn_cnic.to_s.presence || '0000000',
        sellerBusinessName: user.business_name.to_s.presence || 'Test Seller',
        sellerProvince: 'Punjab',
        sellerAddress: user.address.to_s.presence || 'Test Address',
        buyerNTNCNIC: spec[:buyer_ntn],
        buyerBusinessName: spec[:buyer_name],
        buyerProvince: 'Punjab',
        buyerAddress: spec[:buyer_address],
        buyerRegistrationType: spec[:buyer_registration_type],
        invoiceRefNo: "TEST-#{spec[:scenario_id]}-#{Time.current.to_i}",
        scenarioId: spec[:scenario_id],
        items: [spec[:item]]
      }
    end

    def persist_invoice(spec, payload, response)
      item_data = payload[:items].first
      tax_rate = parse_tax_rate(item_data[:rate])
      value_excl = item_data[:valueSalesExcludingST].to_f
      tax_amount = item_data[:salesTaxApplicable].to_f
      quantity = item_data[:quantity].to_f

      invoice = user.invoices.create!(
        invoice_date: Date.today,
        invoice_type: 'Sale Invoice',
        scenario_id: spec[:scenario_id],
        buyer_ntn: payload[:buyerNTNCNIC],
        buyer_name: payload[:buyerBusinessName],
        buyer_province: payload[:buyerProvince],
        buyer_address: payload[:buyerAddress],
        buyer_registration_type: payload[:buyerRegistrationType],
        seller_ntn: payload[:sellerNTNCNIC],
        seller_name: payload[:sellerBusinessName],
        seller_province: payload[:sellerProvince],
        seller_address: payload[:sellerAddress],
        status: response[:success] ? 'approved' : 'failed',
        fbr_status: response[:success] ? 'submitted' : 'failed',
        fbr_invoice_id: response[:fbr_invoice_id],
        response_data: response[:data],
        error_message: response[:error_message],
        submitted_at: response[:success] ? Time.current : nil,
        tax_amount: tax_amount,
        total_amount: value_excl + tax_amount,
        test_data: { sandbox_test: true, scenario_name: spec[:name] }
      )

      unit_price = value_excl.positive? ? (value_excl / quantity).round(2) : item_data[:fixedNotifiedValueOrRetailPrice].to_f

      invoice.items.create!(
        hs_code: item_data[:hsCode],
        description: item_data[:productDescription],
        quantity: quantity,
        uom: item_data[:uoM],
        unit_price: unit_price,
        tax_rate: tax_rate,
        sales_tax: tax_amount,
        total_value: value_excl.positive? ? value_excl : item_data[:fixedNotifiedValueOrRetailPrice].to_f,
        sale_type: item_data[:saleType]
      )

      invoice
    end

    def scenario_specs
      [
        spec('SN001', 'Goods at standard rate to registered buyers', 'Registered', '0225898', 'Nishat Chunian Limited',
             standard_item('9401.4100', 'Wooden plates (standard rate)')),
        spec('SN002', 'Goods at standard rate to unregistered buyers', 'Unregistered', '1234567890123', 'Walk-in Customer',
             standard_item('9401.4100', 'Wooden plates (unregistered buyer)')),
        spec('SN005', 'Reduced rate sale', 'Registered', '0225898', 'Nishat Chunian Limited',
             reduced_rate_item),
        spec('SN006', 'Exempt goods sale', 'Registered', '0225898', 'Nishat Chunian Limited',
             exempt_item),
        spec('SN007', 'Zero rated sale', 'Registered', '0225898', 'Nishat Chunian Limited',
             zero_rated_item),
        spec('SN008', 'Sale of 3rd schedule goods', 'Registered', '0225898', 'Nishat Chunian Limited',
             third_schedule_item)
      ]
    end

    def spec(scenario_id, name, buyer_registration_type, buyer_ntn, buyer_name, item)
      {
        scenario_id: scenario_id,
        name: name,
        buyer_registration_type: buyer_registration_type,
        buyer_ntn: buyer_ntn,
        buyer_name: buyer_name,
        buyer_address: '31Q Gulberg-2 Lahore, Pakistan',
        item: item
      }
    end

    def standard_item(hs_code, description)
      value_excl = LINE_VALUE
      tax = sales_tax_for(value_excl, '18%')

      base_item(
        hs_code: hs_code,
        description: description,
        rate: '18%',
        sale_type: 'Goods at standard rate (default)',
        value_excl: value_excl,
        tax: tax
      )
    end

    def reduced_rate_item
      value_excl = LINE_VALUE
      tax = sales_tax_for(value_excl, '1%')

      base_item(
        hs_code: '0102.2930',
        description: 'Reduced rate product',
        rate: '1%',
        sale_type: 'Goods at Reduced Rate',
        value_excl: value_excl,
        tax: tax,
        sro_schedule_no: 'EIGHTH SCHEDULE Table 1',
        sro_item_serial_no: '82'
      )
    end

    def exempt_item
      base_item(
        hs_code: '0102.2930',
        description: 'Exempt product',
        rate: 'Exempt',
        sale_type: 'Exempt goods',
        value_excl: LINE_VALUE,
        tax: 0,
        sro_schedule_no: '6th Schd Table I',
        sro_item_serial_no: '100'
      )
    end

    def zero_rated_item
      base_item(
        hs_code: '0101.2100',
        description: 'Zero rated product',
        rate: '0%',
        sale_type: 'Goods at zero-rate',
        value_excl: LINE_VALUE,
        tax: 0,
        sro_schedule_no: '327(I)/2008',
        sro_item_serial_no: '1',
        extra_tax: 0
      )
    end

    def third_schedule_item
      retail_price = LINE_VALUE
      value_excl = LINE_VALUE
      tax = sales_tax_for(retail_price, '18%')

      base_item(
        hs_code: '0101.2100',
        description: '3rd schedule product',
        rate: '18%',
        sale_type: '3rd Schedule Goods',
        value_excl: value_excl,
        tax: tax,
        retail_price: retail_price,
        total_values: 0
      )
    end

    def base_item(hs_code:, description:, rate:, sale_type:, value_excl:, tax:, quantity: 1,
                  retail_price: 0, total_values: 0, sro_schedule_no: '', sro_item_serial_no: '',
                  extra_tax: '')
      {
        hsCode: hs_code,
        productDescription: description,
        rate: rate,
        uoM: 'Numbers, pieces, units',
        quantity: quantity,
        totalValues: total_values,
        valueSalesExcludingST: value_excl,
        fixedNotifiedValueOrRetailPrice: retail_price,
        salesTaxApplicable: tax,
        salesTaxWithheldAtSource: 0,
        extraTax: extra_tax,
        furtherTax: 0,
        sroScheduleNo: sro_schedule_no,
        fedPayable: 0,
        discount: 0,
        saleType: sale_type,
        sroItemSerialNo: sro_item_serial_no
      }
    end

    def sales_tax_for(value, rate)
      rate_str = rate.to_s.strip
      return 0 if rate_str.casecmp('exempt').zero? || rate_str == '0%'

      pct = rate_str.delete('%').to_f
      (value * pct / 100).round(2)
    end

    def parse_tax_rate(rate)
      rate_str = rate.to_s.strip
      return 0.0 if rate_str.casecmp('exempt').zero?

      rate_str.delete('%').to_f
    end
  end
end
