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

    def fetch(fbr_invoice_number)
      number = fbr_invoice_number.to_s.strip
      return { success: false, error_message: 'FBR invoice number is required.' } if number.blank?

      local = @user.invoices.find_by(fbr_invoice_id: number)
      api_result = request_from_fbr(number)

      if api_result[:success]
        merge_local_response!(local, api_result[:data]) if local
        {
          success: true,
          data: api_result[:data],
          source: api_result[:source],
          local_invoice: local
        }
      elsif local
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
          data: api_result[:data]
        }
      end
    end

    def sync_invoice!(invoice)
      return { success: false, error_message: 'Invoice has no FBR number.' } if invoice.fbr_invoice_id.blank?

      result = fetch(invoice.fbr_invoice_id)
      return result unless result[:success]

      if result[:data].present?
        merged = (invoice.response_data || {}).merge('iris_sync' => result[:data], 'iris_synced_at' => Time.current.iso8601)
        merged['QRCode'] ||= extract_qr(result[:data])
        invoice.update!(response_data: merged)
      end

      { success: true, source: result[:source], data: result[:data] }
    end

    private

    def request_from_fbr(number)
      return { success: false, error_message: 'FBR token is not configured.' } if @token.blank?

      GET_ENDPOINTS[@environment].each do |endpoint|
        url = "#{DI_BASE[@environment]}/#{endpoint}"
        result = try_post(url, di_payload(number))
        return result.merge(source: endpoint) if result[:success]
      end

      legacy = try_post(LEGACY_URL, legacy_payload(number))
      return legacy.merge(source: 'GetInvoiceDetails') if legacy[:success]

      { success: false, error_message: legacy[:error_message] || 'Could not retrieve invoice from FBR.', data: legacy[:data] }
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
        { success: false, error_message: message, data: data }
      end
    rescue StandardError => e
      Rails.logger.error "FBR Iris fetch failed (#{url}): #{e.message}"
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
      return data['errorMessage'] if data['errorMessage'].present?
      return data['validationResponse']['error'] if data.dig('validationResponse', 'error').present?

      data['error'] if data['error'].present?
    end

    def extract_qr(data)
      return nil unless data.is_a?(Hash)

      data['QRCode'] || data['qrCode'] || data['qr_code']
    end

    def merge_local_response!(invoice, fbr_data)
      merged = (invoice.response_data || {}).merge('iris_sync' => fbr_data, 'iris_synced_at' => Time.current.iso8601)
      qr = extract_qr(fbr_data)
      merged['QRCode'] = qr if qr.present?
      invoice.update!(response_data: merged)
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
