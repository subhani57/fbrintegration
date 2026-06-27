# frozen_string_literal: true

module Fbr
  # Verifies buyer NTN/CNIC against FBR dist APIs (Get_Reg_Type + STATL).
  # NTN must be 7 digits with leading zeros (e.g. 0698469) — without padding FBR returns wrong results.
  class BuyerVerificationService
    def initialize(user)
      @reference = ReferenceService.new(user)
    end

    def verify(raw_number)
      normalized = normalize_registration_no(raw_number)
      return failure('Invalid registration number') if normalized.blank?

      reg_type_data = @reference.registration_type(registration_no: normalized)
      statl_data = @reference.statl(registration_no: normalized)

      registration_type = resolve_registration_type(reg_type_data, statl_data)
      atl_status = extract_statl_status(statl_data)

      {
        success: registration_type.present?,
        registration_no: normalized,
        registration_type: registration_type,
        registered: registration_type == 'Registered',
        atl_status: atl_status,
        atl_active: atl_active?(statl_data),
        get_reg_type: reg_type_data,
        statl: statl_data
      }
    end

    def self.normalize_registration_no(raw)
      value = raw.to_s.strip.gsub(/\s+/, '')
      return nil if value.blank?

      if value.match?(/\A(\d{7})-\d\z/)
        return Regexp.last_match(1)
      end

      if value.match?(/\A\d{5}-\d{7}-\d\z/)
        return value.delete('-')
      end

      digits = value.gsub(/\D/, '')
      return nil if digits.blank?

      return digits.rjust(7, '0') if digits.length <= 7

      digits
    end

    private

    def normalize_registration_no(raw)
      self.class.normalize_registration_no(raw)
    end

    def resolve_registration_type(get_reg, statl)
      atl_ok = atl_active?(statl)

      if get_reg.is_a?(Hash)
        code = get_reg['statuscode'].to_s.strip
        return 'Registered' if code == '00'

        reg_type = get_reg['REGISTRATION_TYPE'].to_s.strip.downcase
        return 'Registered' if reg_type == 'registered'

        # STATL Active matches IRIS "Taxpayer is Active" — use when Get_Reg_Type is inconclusive
        return 'Registered' if atl_ok

        return 'Unregistered' if reg_type.in?(%w[unregistered un-registered])
      end

      return 'Registered' if atl_ok

      'Unregistered'
    end

    def atl_active?(statl)
      extract_statl_status(statl).casecmp('active').zero?
    end

    def extract_statl_status(statl)
      return nil unless statl.is_a?(Hash)

      statl['status'].to_s.strip.presence
    end

    def failure(message)
      { success: false, error: message }
    end
  end
end
