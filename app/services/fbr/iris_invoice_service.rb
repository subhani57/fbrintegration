# frozen_string_literal: true

module Fbr
  # Fetch invoice details registered on FBR / IRIS Digital Invoicing.
  # Production DI API v1.12 documents post + validate only; retrieval uses
  # documented sandbox GetInvoiceDetails and optional getinvoicedata endpoints.
  class IrisInvoiceService
    include HTTParty

    DI_BASE = {
      sandbox: 'https://gw.fbr.gov.pk/di_data/v1/di',
      production: 'https://gw.fbr.gov.pk/di_data/v1/di'
    }.freeze

    GET_ENDPOINTS = {
      sandbox: %w[getinvoicedata_sb getinvoicedata GetInvoiceDetails],
      production: %w[getinvoicedata GetInvoiceDetails]
    }.freeze

    LEGACY_URL = 'https://gw.fbr.gov.pk/DigitalInvoicing/v1/GetInvoiceDetails'

    def initialize(user, environment = nil)
      @user = user
      @environment = (environment || user.default_fbr_environment).to_sym
      @config = user.configuration_for(@environment)
      @token = @config&.token.presence || env_fallback_token
    end

    def fetch(fbr_invoice_number, allow_local_fallback: true)
      number = fbr_invoice_number.to_s.strip
      return { success: false, error_message: 'FBR invoice number is required.' } if number.blank?

      local = @user.invoices.find_by(fbr_invoice_id: number)
      api_result = request_from_fbr(number)

      if api_result[:success]
        merge_local_response!(local, api_result[:data]) if local
        return {
          success: true,
          data: api_result[:data],
          source: api_result[:source],
          environment: api_result[:environment],
          local_invoice: local
        }
      end

      iris_status = detect_iris_status(api_result[:data], error_message: api_result[:error_message])
      if iris_status == :cancelled
        return {
          success: true,
          data: api_result[:data],
          source: api_result[:source] || 'iris',
          environment: api_result[:environment],
          local_invoice: local,
          iris_status: :cancelled
        }
      end

      if local && allow_local_fallback
        {
          success: true,
          data: local.response_data.presence || local_fbr_payload(local),
          source: 'local',
          local_invoice: local,
          notice: 'FBR live lookup unavailable — showing your saved copy of this invoice.'
        }
      else
        {
          success: false,
          error_message: api_result[:error_message] || 'Invoice not found on FBR or in your account.',
          data: api_result[:data],
          api_unavailable: api_lookup_unavailable?(api_result[:error_message])
        }
      end
    end

    def sync_invoice!(invoice)
      return { success: false, error_message: 'Invoice has no FBR number.' } if invoice.fbr_invoice_id.blank?

      api_result = fetch_live_status(invoice.fbr_invoice_id, invoice: invoice)
      iris_status = api_result[:iris_status] ||
        detect_iris_status(api_result[:data], error_message: api_result[:error_message])

      if api_result[:success] && api_result[:data].present?
        apply_sync_data!(invoice, api_result[:data])
        apply_iris_status!(invoice, iris_status, api_result[:data])
        return {
          success: true,
          source: api_result[:source],
          environment: api_result[:environment],
          data: api_result[:data],
          iris_status: iris_status,
          notice: iris_status == :cancelled ? 'Invoice was cancelled on IRIS.' : nil
        }
      end

      if iris_status == :cancelled && invoice_submitted_on_fbr?(invoice)
        invoice.apply_iris_cancellation!(
          source_data: api_result[:data],
          message: api_result[:error_message].presence || 'Cancelled on FBR IRIS.'
        )
        return {
          success: true,
          source: 'iris',
          data: api_result[:data],
          iris_status: :cancelled,
          notice: 'Invoice was cancelled on IRIS — local status updated.'
        }
      end

      if api_result[:api_unavailable]
        return {
          success: false,
          api_unavailable: true,
          error_message: 'FBR invoice lookup is not available for your token (403/404). ' \
                         'If you cancelled this invoice on IRIS, use "Mark cancelled on IRIS" instead.',
          iris_status: iris_status
        }
      end

      {
        success: false,
        error_message: api_result[:error_message] || 'Could not sync from IRIS.',
        data: api_result[:data],
        iris_status: iris_status
      }
    end

    private

    def fetch_live_status(number, invoice: nil)
      last_result = nil

      environments_for_invoice(invoice).each do |environment|
        service = self.class.new(@user, environment)
        next unless service.send(:token_configured?)

        result = service.send(:request_from_fbr, number).merge(environment: environment)
        iris_status = detect_iris_status(result[:data], error_message: result[:error_message])
        result[:iris_status] = iris_status

        return result if result[:success]
        return result if iris_status == :cancelled

        last_result = result
      end

      last_result || {
        success: false,
        error_message: 'FBR token is not configured.',
        api_unavailable: true
      }
    end

    def environments_for_invoice(invoice)
      envs = []
      stored = invoice&.response_data&.dig('submitted_environment')
      envs << stored.to_sym if stored.present?
      envs << @environment
      envs << :production
      envs << :sandbox
      envs.uniq
    end

    def token_configured?
      @token.present?
    end

    def request_from_fbr(number)
      return { success: false, error_message: 'FBR token is not configured.' } if @token.blank?

      GET_ENDPOINTS[@environment].each do |endpoint|
        url = "#{DI_BASE[@environment]}/#{endpoint}"
        result = try_post(url, di_payload(number))
        return result.merge(source: endpoint) if result[:success]
      end

      legacy = try_post(LEGACY_URL, legacy_payload(number))
      return legacy.merge(source: 'GetInvoiceDetails') if legacy[:success]

      {
        success: false,
        error_message: legacy[:error_message] || 'Could not retrieve invoice from FBR.',
        data: legacy[:data],
        api_unavailable: api_lookup_unavailable?(legacy[:error_message])
      }
    end

    def api_lookup_unavailable?(message)
      message.to_s.match?(/403|404|forbidden|not found|No matching resource|900908/i)
    end

    def try_post(url, payload)
      response = self.class.post(
        url,
        body: payload.to_json,
        headers: request_headers,
        timeout: 45
      )

      data = parse_body(response)
      return { success: false, error_message: 'Empty response from FBR.', data: data } if data.blank?

      if response_success?(response, data)
        { success: true, data: data }
      else
        message = extract_error(data) || "FBR returned HTTP #{response.code}"
        { success: false, error_message: message, data: data, http_code: response.code.to_i }
      end
    rescue StandardError => e
      AppLogger.error('fbr.iris.fetch_failed', exception: e, url: url, user_id: @user.id)
      { success: false, error_message: e.message }
    end

    def di_payload(number)
      {
        invoiceNumber: number,
        sellerNTNCNIC: @user.ntn_cnic.to_s
      }
    end

    def legacy_payload(number)
      {
        InvoiceNumber: number,
        invoiceNumber: number,
        POSID: 0,
        USIN: number
      }
    end

    def request_headers
      {
        'Authorization' => "Bearer #{@token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'User-Agent' => 'FBR-Integration/1.0'
      }
    end

    def parse_body(response)
      if response.parsed_response.present?
        response.parsed_response
      else
        JSON.parse(response.body)
      end
    rescue JSON::ParserError
      { 'raw' => response.body.to_s }
    end

    def response_success?(response, data)
      return true if response.code.to_i.between?(200, 299) && invoice_data_present?(data)

      validation = data['validationResponse']
      return true if validation.is_a?(Hash) && validation['statusCode'] == '00'

      status = data['statusCode'] || data['StatusCode']
      return true if status.to_s.in?(%w[200 00 0])

      data['invoiceNumber'].present? || data['result'].present?
    end

    def invoice_data_present?(data)
      return false unless data.is_a?(Hash)

      %w[invoiceNumber InvoiceNumber result invoiceType buyerBusinessName items].any? do |key|
        data[key].present?
      end
    end

    def extract_error(data)
      return data.dig('fault', 'description') if data.dig('fault', 'description').present?
      return data.dig('fault', 'message') if data.dig('fault', 'message').present?
      return data['errorMessage'] if data['errorMessage'].present?
      return data['validationResponse']['error'] if data.dig('validationResponse', 'error').present?

      data['error'] if data['error'].present?
    end

    def extract_qr(data)
      return nil unless data.is_a?(Hash)

      data['QRCode'] || data['qrCode'] || data['qr_code']
    end

    def merge_local_response!(invoice, fbr_data)
      apply_sync_data!(invoice, fbr_data)
    end

    def apply_sync_data!(invoice, fbr_data)
      merged = (invoice.response_data || {}).merge(
        'iris_sync' => fbr_data,
        'iris_synced_at' => Time.current.iso8601
      )
      qr = extract_qr(fbr_data)
      merged['QRCode'] = qr if qr.present?
      invoice.update!(response_data: merged)
    end

    def apply_iris_status!(invoice, iris_status, data)
      case iris_status
      when :cancelled
        invoice.apply_iris_cancellation!(source_data: data)
      end
    end

    def detect_iris_status(data, error_message: nil)
      return :cancelled if cancellation_error?(error_message)
      return :unknown unless data.is_a?(Hash)

      iris_status_values(data).any? { |value| cancelled_status_value?(value) } ? :cancelled : :active
    end

    def iris_status_values(data)
      values = [
        data['status'],
        data['Status'],
        data['invoiceStatus'],
        data['InvoiceStatus'],
        data['fbrStatus'],
        data['FBRStatus'],
        data.dig('validationResponse', 'status'),
        data.dig('result', 'status')
      ]
      Array(data['invoiceStatuses']).each do |entry|
        next unless entry.is_a?(Hash)

        values << entry['status']
        values << entry['Status']
      end
      values.compact
    end

    def cancelled_status_value?(value)
      value.to_s.strip.match?(/\A(cancelled|canceled|deleted|void|voided|inactive)\z/i)
    end

    def cancellation_error?(message)
      return false if message.blank?

      message.match?(/cancel(l)?ed|deleted|void|not found|does not exist|invalid invoice|no record|already cancel/i)
    end

    def invoice_submitted_on_fbr?(invoice)
      invoice.fbr_invoice_id.present? &&
        (invoice.fbr_status == 'submitted' || %w[submitted approved].include?(invoice.status))
    end

    def local_fbr_payload(invoice)
      {
        'invoiceNumber' => invoice.fbr_invoice_id,
        'dated' => invoice.submitted_at&.iso8601,
        'invoiceType' => invoice.invoice_type,
        'buyerBusinessName' => invoice.buyer_name,
        'buyerNTNCNIC' => invoice.buyer_ntn,
        'total_amount' => invoice.total_amount,
        'tax_amount' => invoice.tax_amount
      }
    end

    def env_fallback_token
      key = @environment == :production ? 'FBR_PRODUCTION_TOKEN' : 'FBR_SANDBOX_TOKEN'
      ENV[key].presence
    end
  end
end
