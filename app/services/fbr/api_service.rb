# app/services/fbr/api_service.rb
module Fbr
  class ApiService
    include HTTParty
    format :json

    BASE_URLS = {
      sandbox: 'https://gw.fbr.gov.pk/di_data/v1/di',
      production: 'https://gw.fbr.gov.pk/di_data/v1/di'
    }.freeze

    ENDPOINTS = {
      post_invoice: {
        sandbox: 'postinvoicedata_sb',
        production: 'postinvoicedata'
      },
      validate_invoice: {
        sandbox: 'validateinvoicedata_sb',
        production: 'validateinvoicedata'
      }
    }.freeze

    def initialize(user, environment = :sandbox, cookies: nil)
      @user = user
      @environment = environment.to_sym
      @cookies = cookies
      @config = resolve_configuration(user)
      @token = @config&.token.presence || env_fallback_token
    end

    def submit_invoice_payload(payload)
      endpoint = ENDPOINTS[:post_invoice][@environment]
      response = post_request(endpoint, payload)
      handle_response(response, OpenStruct.new(id: nil))
    end

    def submit_invoice(invoice)
      validate_configuration
      endpoint = ENDPOINTS[:post_invoice][@environment]
      payload = build_invoice_payload(invoice)
      AppLogger.info('fbr.api.submit_started', invoice_id: invoice.id, user_id: @user.id, environment: @environment)

      response = post_request(endpoint, payload)
      result = handle_response(response, invoice, payload)
      AppLogger.info(
        'fbr.api.submit_finished',
        invoice_id: invoice.id,
        user_id: @user.id,
        environment: @environment,
        success: result[:success]
      )
      result
    end

    def validate_invoice(invoice)
      validate_configuration
      endpoint = ENDPOINTS[:validate_invoice][@environment]
      payload = build_invoice_payload(invoice)
      AppLogger.info('fbr.api.validate_started', invoice_id: invoice.id, user_id: @user.id, environment: @environment)

      response = post_request(endpoint, payload)
      result = handle_response(response, invoice, payload)
      AppLogger.info(
        'fbr.api.validate_finished',
        invoice_id: invoice.id,
        user_id: @user.id,
        environment: @environment,
        success: result[:success]
      )
      result
    end

    private

    def post_request(endpoint, payload)
      url = "#{BASE_URLS[@environment]}/#{endpoint}"

      self.class.post(
        url,
        body: payload.to_json,
        headers: {
          'Authorization' => "Bearer #{@token}",
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'User-Agent' => 'PostmanRuntime/7.49.1',
          'Origin' => 'https://gw.fbr.gov.pk',
          'Connection' => 'keep-alive',
          'Accept-Encoding' => 'gzip, deflate, br',
          'Cookie' => @cookies.to_s
        },
        timeout: 30
      )
    rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout => e
      AppLogger.error('fbr.api.request_failed', exception: e, endpoint: endpoint, environment: @environment, user_id: @user.id)
      OpenStruct.new(body: { error: e.message }.to_json, parsed_response: nil, code: 500)
    end

    def build_invoice_payload(invoice)
      seller_province = invoice.seller_province.presence || @user.seller_province.presence || Company::DEFAULT_PROVINCE
      buyer_province = invoice.buyer_province.presence || Company::DEFAULT_PROVINCE

      payload = {
        invoiceType: invoice.invoice_type || 'Sale Invoice',
        invoiceDate: invoice.invoice_date.strftime('%Y-%m-%d'),
        sellerNTNCNIC: @user.ntn_cnic,
        sellerBusinessName: @user.business_name,
        sellerProvince: seller_province,
        sellerAddress: @user.address,
        buyerNTNCNIC: invoice.buyer_ntn,
        buyerBusinessName: invoice.buyer_name,
        buyerProvince: buyer_province,
        buyerAddress: invoice.buyer_address,
        buyerRegistrationType: invoice.buyer_registration_type || 'Registered',
        invoiceRefNo: invoice.original_invoice_fbr_number.to_s,
        items: build_items_payload(invoice.items)
      }

      payload[:scenarioId] = invoice.scenario_id.presence || 'SN001' if @environment == :sandbox
      payload
    end

    def build_items_payload(items)
      items.map do |item|
        quantity = item.quantity.to_f
        unit_price = item.unit_price.to_f
        total_price = item.total_value || (quantity * unit_price)
        tax_rate = item.tax_rate.to_f
        tax_amount = item.sales_tax || (total_price * tax_rate / 100.0)

        {
          hsCode: item.hs_code.presence,
          productDescription: item.description.to_s.gsub(/[\r\n]+/, ' ').strip,
          rate: "#{tax_rate.to_i}%",
          uoM: item.uom.to_s,
          quantity: quantity.round(2).to_f,
          totalValues: 0,
          valueSalesExcludingST: total_price.round(2).to_f,
          fixedNotifiedValueOrRetailPrice: 0,
          salesTaxApplicable: tax_amount.round(2).to_f,
          salesTaxWithheldAtSource: 0,
          extraTax: '',
          furtherTax: 0,
          sroScheduleNo: item.sro_schedule_no.to_s,
          fedPayable: 0,
          discount: 0,
          saleType: item.sale_type.to_s.presence || 'Goods at standard rate (default)',
          sroItemSerialNo: ''
        }
      end
    end

    def handle_response(response, invoice, request_payload = nil)
      log_request(response, invoice, request_payload)

      data = parse_fbr_response(response)

      validation = data['validationResponse']

      if validation && validation['statusCode'] == '00'
        qr = data['QRCode'] || data['qrCode']
        stored = data.merge('QRCode' => qr) if qr.present?
        { success: true, invoice_number: data['invoiceNumber'], fbr_invoice_id: data['invoiceNumber'], data: stored || data }
      elsif validation
        error_message = extract_validation_error(validation)
        { success: false, error_code: validation['errorCode'], error_message: error_message, data: data }
      else
        { success: false, error_code: 'UNKNOWN', error_message: data['error'] || 'Unexpected FBR response', data: data }
      end
    end

    def parse_fbr_response(response)
      if response.parsed_response.present?
        response.parsed_response
      else
        JSON.parse(response.body)
      end
    rescue JSON::ParserError
      extract_json_from_malformed_fbr_body(response.body.to_s)
    end

    def extract_json_from_malformed_fbr_body(body)
      cleaned = body.gsub(/,\s*}/, '}').gsub(/,\s*\]/, ']')
      JSON.parse(cleaned)
    rescue JSON::ParserError
      item_error = body[/invoiceStatuses[^\]]+"error":"([^"]+)"/, 1]
      { 'error' => item_error || 'Invalid JSON returned from FBR', 'raw_body' => body }
    end

    def extract_validation_error(validation)
      validation['error'].presence ||
        Array(validation['invoiceStatuses']).filter_map { |s| s['error'].presence }.first ||
        validation['errorCode'].presence ||
        'FBR validation failed'
    end

    def validate_configuration
      env_label = @environment == :production ? 'Production' : 'Sandbox'
      raise "#{env_label} FBR token is not configured." unless @token
    end

    def resolve_configuration(user)
      return nil unless user.respond_to?(:configuration_for)

      user.configuration_for(@environment)
    end

    def env_fallback_token
      key = @environment == :production ? 'FBR_PRODUCTION_TOKEN' : 'FBR_SANDBOX_TOKEN'
      ENV[key].presence
    end

    def log_request(response, invoice, request_payload = nil)
      return unless defined?(FbrLog)

      endpoint = response.respond_to?(:request) ? response.request.last_uri.to_s : nil
      FbrLog.create!(
        user: @user,
        invoice: invoice.is_a?(Invoice) ? invoice : nil,
        log_type: 'api_call',
        endpoint: endpoint,
        request_body: request_payload&.to_json,
        response_body: response.body.to_s,
        status_code: response.code,
        environment: @environment.to_s
      )
    rescue StandardError => e
      AppLogger.error('fbr.api.log_persist_failed', exception: e, user_id: @user.id, invoice_id: invoice.is_a?(Invoice) ? invoice.id : nil)
    end
  end
end
