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
    SYNC_HTTP_TIMEOUT = 12

    def initialize(user, environment = nil)
      @user = user
      @environment = (environment || user.default_fbr_environment).to_sym
      @config = user.configuration_for(@environment)
      @token = @config&.token.presence || env_fallback_token
    end

    def fetch(fbr_invoice_number, allow_local_fallback: true, invoice: nil)
      number = fbr_invoice_number.to_s.strip
      return { success: false, error_message: 'FBR invoice number is required.' } if number.blank?

      local = invoice || @user.invoices.find_by(fbr_invoice_id: number)
      api_result = request_from_fbr(number, invoice: local)

      if api_result[:success]
        merge_local_response!(local, api_result[:data]) if local
        return {
          success: true,
          data: api_result[:data],
          source: api_result[:source],
          environment: api_result[:environment] || @environment,
          local_invoice: local
        }
      end

      iris_status = detect_iris_status(api_result[:data], error_message: api_result[:error_message])
      if iris_status == :cancelled
        return {
          success: true,
          data: api_result[:data],
          source: api_result[:source] || 'iris',
          environment: api_result[:environment] || @environment,
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
          api_unavailable: api_lookup_unavailable?(api_result[:error_message], api_result[:http_code])
        }
      end
    end

    def sync_invoice!(invoice)
      return { success: false, error_message: 'Invoice has no FBR number.' } if invoice.fbr_invoice_id.blank?

      api_result = fetch_live_status(invoice.fbr_invoice_id, invoice: invoice, fast: true)
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
          notice: sync_notice(iris_status, api_result[:source])
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

      if api_result[:api_unavailable] && local_sync_data(invoice).present?
        apply_sync_data!(invoice, local_sync_data(invoice))
        return {
          success: true,
          source: 'local',
          data: local_sync_data(invoice),
          iris_status: :active,
          notice: 'FBR live lookup is unavailable for your token — refreshed from your saved submission data.'
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

    def sync_notice(iris_status, source)
      return 'Invoice was cancelled on IRIS.' if iris_status == :cancelled

      "Synced from IRIS (#{source})."
    end

    def fetch_live_status(number, invoice: nil, fast: false)
      return fetch_live_status_fast(number, invoice: invoice) if fast

      last_result = nil

      environments_for_invoice(invoice).each do |environment|
        service = self.class.new(@user, environment)
        next unless service.send(:token_configured?)

        result = service.send(:request_from_fbr, number, invoice: invoice).merge(environment: environment)
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

    def fetch_live_status_fast(number, invoice: nil)
      environments_for_invoice(invoice).each do |environment|
        service = self.class.new(@user, environment)
        next unless service.send(:token_configured?)

        result = service.send(:request_from_fbr, number, invoice: invoice, fast: true).merge(environment: environment)
        iris_status = detect_iris_status(result[:data], error_message: result[:error_message])
        result[:iris_status] = iris_status

        return result if result[:success]
        return result if iris_status == :cancelled
      end

      {
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

    def request_from_fbr(number, invoice: nil, fast: false)
      return request_from_fbr_fast(number, invoice: invoice) if fast

      return { success: false, error_message: 'FBR token is not configured.' } if @token.blank?

      last_result = nil

      seller_ntn_candidates(invoice).each do |ntn|
        GET_ENDPOINTS[@environment].each do |endpoint|
          url = "#{DI_BASE[@environment]}/#{endpoint}"
          payload_variants(number, ntn).each do |payload|
            result = try_post(url, payload)
            if result[:success]
              return result.merge(source: endpoint, seller_ntn: ntn)
            end

            result = try_get(url, payload)
            if result[:success]
              return result.merge(source: endpoint, seller_ntn: ntn)
            end

            last_result = result
          end
        end

        legacy = try_post(LEGACY_URL, legacy_payload(number, ntn))
        return legacy.merge(source: 'GetInvoiceDetails', seller_ntn: ntn) if legacy[:success]

        last_result = legacy if last_result.nil? || legacy[:http_code].to_i >= last_result[:http_code].to_i
      end

      {
        success: false,
        error_message: last_result&.dig(:error_message) || 'Could not retrieve invoice from FBR.',
        data: last_result&.dig(:data),
        http_code: last_result&.dig(:http_code),
        api_unavailable: api_lookup_unavailable?(last_result&.dig(:error_message), last_result&.dig(:http_code))
      }
    end

    def request_from_fbr_fast(number, invoice: nil)
      return { success: false, error_message: 'FBR token is not configured.', api_unavailable: true } if @token.blank?

      ntn = seller_ntn_candidates(invoice).first
      return { success: false, error_message: 'Seller NTN is required for IRIS lookup.', api_unavailable: true } if ntn.blank?

      last_result = nil
      endpoint = GET_ENDPOINTS[@environment].first
      payload = payload_variants(number, ntn).first
      url = "#{DI_BASE[@environment]}/#{endpoint}"

      last_result = try_post(url, payload, timeout: SYNC_HTTP_TIMEOUT)
      return last_result.merge(source: endpoint, seller_ntn: ntn) if last_result[:success]

      last_result = try_get(url, payload, timeout: SYNC_HTTP_TIMEOUT)
      return last_result.merge(source: endpoint, seller_ntn: ntn) if last_result[:success]

      legacy = try_post(LEGACY_URL, legacy_payload(number, ntn), timeout: SYNC_HTTP_TIMEOUT)
      return legacy.merge(source: 'GetInvoiceDetails', seller_ntn: ntn) if legacy[:success]

      {
        success: false,
        error_message: last_result&.dig(:error_message) || legacy[:error_message] || 'Could not retrieve invoice from FBR.',
        data: last_result&.dig(:data) || legacy[:data],
        http_code: last_result&.dig(:http_code) || legacy[:http_code],
        api_unavailable: api_lookup_unavailable?(
          last_result&.dig(:error_message) || legacy[:error_message],
          last_result&.dig(:http_code) || legacy[:http_code]
        )
      }
    end

    def seller_ntn_candidates(invoice)
      candidates = [
        invoice&.seller_ntn,
        @user.ntn_cnic,
        invoice&.user&.ntn_cnic
      ].flat_map { |value| ntn_variants(value) }

      candidates.uniq.reject(&:blank?)
    end

    def ntn_variants(value)
      raw = value.to_s.strip
      return [] if raw.blank?

      digits = raw.gsub(/\D/, '')
      [raw, digits].uniq
    end

    def payload_variants(number, ntn)
      [
        { invoiceNumber: number, sellerNTNCNIC: ntn },
        { InvoiceNumber: number, sellerNTNCNIC: ntn },
        { invoiceNumber: number, NTNCNIC: ntn },
        { invoiceNo: number, sellerNTNCNIC: ntn }
      ].uniq
    end

    def api_lookup_unavailable?(message, http_code = nil)
      return true if http_code.to_i.in?([403, 404])

      message.to_s.match?(/403|404|forbidden|No matching resource|900908/i)
    end

    def try_post(url, payload, timeout: 45)
      response = self.class.post(
        url,
        body: payload.to_json,
        headers: request_headers,
        timeout: timeout
      )

      parse_response(response)
    rescue StandardError => e
      AppLogger.error('fbr.iris.fetch_failed', exception: e, url: url, user_id: @user.id)
      { success: false, error_message: e.message }
    end

    def try_get(url, payload, timeout: 45)
      response = self.class.get(
        url,
        query: payload,
        headers: request_headers,
        timeout: timeout
      )

      parse_response(response)
    rescue StandardError => e
      AppLogger.error('fbr.iris.fetch_failed', exception: e, url: url, user_id: @user.id)
      { success: false, error_message: e.message }
    end

    def parse_response(response)
      data = normalize_data(parse_body(response))
      return { success: false, error_message: 'Empty response from FBR.', data: data, http_code: response.code.to_i } if data.blank?

      if response_success?(response, data)
        { success: true, data: data }
      else
        message = extract_error(data) || "FBR returned HTTP #{response.code}"
        {
          success: false,
          error_message: message,
          data: data,
          http_code: response.code.to_i,
          api_unavailable: api_lookup_unavailable?(message, response.code.to_i)
        }
      end
    end

    def di_payload(number, invoice: nil)
      payload_variants(number, seller_ntn_candidates(invoice).first.to_s).first
    end

    def legacy_payload(number, ntn)
      {
        InvoiceNumber: number,
        invoiceNumber: number,
        sellerNTNCNIC: ntn,
        POSID: 0,
        USIN: number
      }
    end

    def request_headers
      {
        'Authorization' => "Bearer #{@token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'User-Agent' => 'PostmanRuntime/7.49.1',
        'Origin' => 'https://gw.fbr.gov.pk',
        'Connection' => 'keep-alive',
        'Accept-Encoding' => 'gzip, deflate, br'
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

    def normalize_data(data)
      return data unless data.is_a?(Hash)

      nested = data['result'] || data['data'] || data['invoice'] || data['Invoice']
      return data unless nested.is_a?(Hash)

      data.merge(nested)
    end

    def response_success?(response, data)
      return true if response.code.to_i.between?(200, 299) && invoice_data_present?(data)

      validation = data['validationResponse']
      return true if validation.is_a?(Hash) && validation['statusCode'] == '00'
      return true if validation.is_a?(Hash) && validation['status'].to_s.casecmp('valid').zero?

      status = data['statusCode'] || data['StatusCode']
      return true if status.to_s.in?(%w[200 00 0])

      data['invoiceNumber'].present? || data['InvoiceNumber'].present? || data['result'].present?
    end

    def invoice_data_present?(data)
      return false unless data.is_a?(Hash)

      %w[invoiceNumber InvoiceNumber invoiceType buyerBusinessName items dated validationResponse QRCode qrCode].any? do |key|
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
      merged = (invoice.response_data || {}).deep_merge(
        'iris_sync' => fbr_data,
        'iris_synced_at' => Time.current.iso8601
      )
      qr = extract_qr(fbr_data)
      merged['QRCode'] = qr if qr.present?
      invoice.update!(response_data: merged)
      invoice.generate_qr_code if qr.blank? && invoice.fbr_invoice_id.present? && invoice.respond_to?(:generate_qr_code)
    end

    def apply_iris_status!(invoice, iris_status, data)
      case iris_status
      when :cancelled
        invoice.apply_iris_cancellation!(source_data: data)
      end
    end

    def local_sync_data(invoice)
      return nil unless invoice.response_data.is_a?(Hash)

      saved = invoice.response_data.except('iris_sync', 'iris_synced_at', 'iris_cancelled_at')
      return saved if saved['invoiceNumber'].present? || saved['validationResponse'].present?

      invoice.response_data['iris_sync']
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

      message.match?(/cancel(l)?ed|deleted|void|already cancel/i)
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
