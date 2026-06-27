# app/services/fbr/reference_service.rb
module Fbr
  class ReferenceService
    BASE_URL = 'https://gw.fbr.gov.pk/pdi/v1'

    def initialize(user = nil)
      @user = user
    end
    
    def provinces
      get('provinces')
    end
    
    def document_types
      get('doctypecode')
    end
    
    def items
      get('itemdesccode')
    end
    
    def uom
      get('uom')
    end
    
    def sro_schedule(date: Date.today, rate_id: nil, origination_supplier: 1)
      params = {
        date: date.strftime('%d-%b-%Y'),
        origination_supplier_csv: origination_supplier
      }
      params[:rate_id] = rate_id if rate_id
      
      get_with_params('SroSchedule', params)
    end
    
    def sale_type_to_rate(date: Date.today, trans_type_id: nil, origination_supplier: 1)
      params = {
        date: date.strftime('%d-%b-%Y'),
        originationSupplier: origination_supplier
      }
      params[:transTypeId] = trans_type_id if trans_type_id
      
      get_with_params('SaleTypeToRate', params)
    end
    
    def hs_uom(hs_code:, annexure_id: 3)
      token = bearer_token
      return nil if token.blank?

      params = {
        hs_code: hs_code,
        annexure_id: annexure_id
      }
      
      base_url = 'https://gw.fbr.gov.pk/pdi/v2'
      url = "#{base_url}/HS_UOM?#{URI.encode_www_form(params)}"
      response = Faraday.get(url) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.headers['Accept'] = 'application/json'
        req.options.timeout = 30
        req.options.open_timeout = 10
      end
      if response.success?
        JSON.parse(response.body)
      else
        AppLogger.error('fbr.reference.hs_uom_error', status: response.status, body: response.body.to_s.truncate(500))
        nil
      end
    rescue => e
      AppLogger.error('fbr.reference.hs_uom_exception', exception: e)
      nil
    end
    
    def sro_item(date: Date.today, sro_id:)
      params = {
        date: date.strftime('%Y-%m-%d'),
        sro_id: sro_id
      }
      
      get_with_params('SROItem', params)
    end
    
    def statl(registration_no:, date: Date.today)
      ntn = BuyerVerificationService.normalize_registration_no(registration_no) || registration_no.to_s.strip
      dist_request('https://gw.fbr.gov.pk/dist/v1/statl', {
        regno: ntn,
        date: date.strftime('%Y-%m-%d')
      })
    end
    
    def registration_type(registration_no:)
      ntn = BuyerVerificationService.normalize_registration_no(registration_no) || registration_no.to_s.strip
      dist_request('https://gw.fbr.gov.pk/dist/v1/Get_Reg_Type', {
        Registration_No: ntn
      })
    end
    
    private

    def get(endpoint)
      token = bearer_token
      return nil if token.blank?

      response = Faraday.get("#{BASE_URL}/#{endpoint}") do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.headers['Accept'] = 'application/json'
        req.options.timeout = 30
        req.options.open_timeout = 10
      end
      if response.success?
        JSON.parse(response.body)
      else
        AppLogger.error('fbr.reference.api_error', status: response.status, body: response.body.to_s.truncate(500))
        nil
      end
    rescue => e
      AppLogger.error('fbr.reference.api_exception', exception: e)
      nil
    end
    
    def get_with_params(endpoint, params)
      token = bearer_token
      return nil if token.blank?

      # Use v2 base URL for v2 endpoints
      base_url = if endpoint.include?('SaleTypeToRate') || endpoint.include?('HS_UOM') || endpoint.include?('SROItem')
                   'https://gw.fbr.gov.pk/pdi/v2'
                 else
                   BASE_URL
                 end
      url = "#{base_url}/#{endpoint}?#{URI.encode_www_form(params)}"
      response = Faraday.get(url) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.headers['Accept'] = 'application/json'
        req.options.timeout = 30
        req.options.open_timeout = 10
      end
      if response.success?
        JSON.parse(response.body)
      else
        AppLogger.error('fbr.reference.api_error', status: response.status, body: response.body.to_s.truncate(500))
        nil
      end
    rescue => e
      AppLogger.error('fbr.reference.api_exception', exception: e)
      nil
    end
    
    # FBR dist endpoints often return HTTP 500 with a valid JSON body — parse regardless of status code.
    def dist_request(url, data, method: :post)
      token = bearer_token
      response = Faraday.public_send(method, url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.headers['Authorization'] = "Bearer #{token}" if token.present?
        req.body = data.to_json
        req.options.timeout = 30
        req.options.open_timeout = 10
      end

      parsed = parse_json_body(response.body)
      if parsed.present?
        parsed['_http_status'] = response.status
        return parsed
      end

      AppLogger.error('fbr.reference.dist_api_error', status: response.status, body: response.body.to_s.truncate(500))
      nil
    rescue StandardError => e
      AppLogger.error('fbr.reference.dist_api_exception', exception: e)
      nil
    end

    def parse_json_body(body)
      return nil if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
    
    def bearer_token
      if @user&.respond_to?(:configuration_for)
        env = @user.default_fbr_environment.to_sym
        user_token = @user.configuration_for(env)&.token.presence
        return user_token if user_token.present?
      end

      ENV['FBR_SANDBOX_TOKEN'].presence || ENV['FBR_PRODUCTION_TOKEN']
    end
  end
end