# app/controllers/api/v1/reference_data_controller.rb
module Api
  module V1
    class ReferenceDataController < Api::BaseController
      before_action :set_reference_service

      def index
        render json: {
          provinces: provinces_data,
          hs_codes: sort_hs_codes(hs_codes_data),
          uom: uom_data,
          document_types: document_types_data
        }
      end

      def provinces
        data = provinces_data
        render json: data
      rescue => e
        Rails.logger.error "Error in provinces: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def hs_codes
        data = sort_hs_codes(hs_codes_data)
        render json: data
      rescue => e
        Rails.logger.error "Error in hs_codes: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def search_hs_codes
        query = params[:q].to_s.strip.downcase
        codes = hs_codes_data

        results = if query.length >= 2
                    codes.select do |item|
                      code = (item[:code] || item['code']).to_s.downcase
                      desc = (item[:description] || item['description']).to_s.downcase
                      code.include?(query) || desc.include?(query)
                    end.first(50)
                  else
                    []
                  end

        render json: results
      rescue => e
        Rails.logger.error "Error in search_hs_codes: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def uom
        data = uom_data
        render json: data
      rescue => e
        Rails.logger.error "Error in uom: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def rates
        date = params[:date] || Date.today
        trans_type_id = params[:trans_type_id]
        origination_supplier = params[:origination_supplier] || 1
        
        data = @reference_service.sale_type_to_rate(
          date: date.to_date,
          trans_type_id: trans_type_id,
          origination_supplier: origination_supplier
        )
        
        render json: data || []
      rescue => e
        Rails.logger.error "Error in rates: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def sro_schedule
        date = params[:date] || Date.today
        rate_id = params[:rate_id]
        origination_supplier = params[:origination_supplier] || 1
        
        data = @reference_service.sro_schedule(
          date: date.to_date,
          rate_id: rate_id,
          origination_supplier: origination_supplier
        )
        
        render json: data || []
      rescue => e
        Rails.logger.error "Error in sro_schedule: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def sro_item
        date = params[:date] || Date.today
        sro_id = params[:sro_id]
        
        return render json: { error: 'sro_id is required' }, status: :bad_request unless sro_id
        
        data = @reference_service.sro_item(
          date: date.to_date,
          sro_id: sro_id
        )
        
        render json: data || []
      rescue => e
        Rails.logger.error "Error in sro_item: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end

      def hs_uom
        hs_code = params[:hs_code]
        annexure_id = params[:annexure_id] || 3
        
        return render json: { error: 'hs_code is required' }, status: :bad_request unless hs_code
        
        begin
          data = @reference_service.hs_uom(
            hs_code: hs_code,
            annexure_id: annexure_id
          )
          render json: data || []
        rescue => e
          Rails.logger.error "Error fetching HS UOM: #{e.message}\n#{e.backtrace.join("\n")}"
          render json: { error: e.message }, status: :internal_server_error
        end
      end

      private

      def set_reference_service
        @reference_service = Fbr::ReferenceService.new(current_user)
      end

      def provinces_data
        Rails.cache.fetch('fbr_provinces', expires_in: 24.hours) do
          data = @reference_service.provinces || []
          data.map do |item|
            {
              code: item['stateProvinceCode'] || item['code'],
              description: item['stateProvinceDesc'] || item['description']
            }
          end
        end
      rescue => e
        Rails.logger.error "Error fetching provinces: #{e.message}"
        []
      end

      def hs_codes_data
        Rails.cache.fetch('fbr_hs_codes_sorted_v1', expires_in: 24.hours) do
          data = @reference_service.items || []
          codes = if data.is_a?(Array) && data.any?
                    data.filter_map do |item|
                      code = item['hS_CODE'] || item['HS_CODE'] || item['code'] || item['hscode']
                      next if code.blank?

                      {
                        code: code,
                        description: item['description'] || item['DESCRIPTION'] || item['desc'] || ''
                      }
                    end
                  else
                    []
                  end
          HsCodeSorting.sort_codes(codes)
        end
      rescue => e
        Rails.logger.error "Error fetching HS codes: #{e.message}\n#{e.backtrace.join("\n")}"
        []
      end

      def sort_hs_codes(codes)
        HsCodeSorting.sort_codes(codes)
      end

      def uom_data
        Rails.cache.fetch('fbr_uom', expires_in: 24.hours) do
          data = @reference_service.uom
          if data && data.is_a?(Array) && data.length > 0
            data.map do |item|
              {
                id: item['uoM_ID'] || item['id'],
                description: item['description']
              }
            end
          else
            # Fallback to common UOM if API fails
            [
              { id: 1, description: 'Numbers, pieces, units' },
              { id: 2, description: 'KG' },
              { id: 3, description: 'Litre' },
              { id: 4, description: 'Metre' },
              { id: 5, description: 'Square Metre' },
              { id: 6, description: 'Cubic Metre' },
              { id: 7, description: 'Ton' },
              { id: 8, description: 'Dozen' }
            ]
          end
        end
      rescue => e
        Rails.logger.error "Error fetching UOM: #{e.message}\n#{e.backtrace.join("\n")}"
        # Return fallback UOM
        [
          { id: 1, description: 'Numbers, pieces, units' },
          { id: 2, description: 'KG' },
          { id: 3, description: 'Litre' },
          { id: 4, description: 'Metre' },
          { id: 5, description: 'Square Metre' },
          { id: 6, description: 'Cubic Metre' }
        ]
      end

      def document_types_data
        Rails.cache.fetch('fbr_document_types', expires_in: 24.hours) do
          data = @reference_service.document_types || []
          data.map do |item|
            {
              id: item['docTypeId'] || item['id'],
              description: item['docDescription'] || item['description']
            }
          end
        end
      rescue => e
        Rails.logger.error "Error fetching document types: #{e.message}"
        []
      end
    end
  end
end
