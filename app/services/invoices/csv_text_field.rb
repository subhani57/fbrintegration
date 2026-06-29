# frozen_string_literal: true

module Invoices
  # Keeps NTN / HS codes intact when CSV is opened or saved in Excel.
  module CsvTextField
    module_function

    # Format a value so Excel treats the cell as text (leading zeros preserved).
    def excel_cell(value)
      return '' if value.blank?

      "=\"#{value.to_s.gsub('"', '""')}\""
    end

    # Parse values exported from Excel or our template back to plain text.
    def normalize(value)
      return nil if value.nil?

      str = value.to_s.strip
      return nil if str.blank?

      str = str.delete_prefix("'").delete_prefix("\t")

      if (match = str.match(/\A="(.*)"\z/m))
        str = match[1].gsub('""', '"')
      elsif (match = str.match(/\A="(.*)\z/m))
        str = match[1]
      end

      str.strip.presence
    end

    def normalize_ntn(value)
      ntn = normalize(value)
      return ntn if ntn.blank?
      return ntn if ntn.include?('-')

      digits = ntn.gsub(/\D/, '')
      return ntn if digits.blank?

      case digits.length
      when 6
        digits.rjust(7, '0')
      when 12
        digits.rjust(13, '0')
      else
        digits
      end
    end

    def normalize_hs_code(value)
      code = normalize(value)
      return code if code.blank?

      if (match = code.match(/\A(\d+)\.(\d+)\z/))
        integer_part = match[1]
        decimal_part = match[2].ljust(4, '0')
        "#{integer_part}.#{decimal_part}"
      else
        code
      end
    end

    def normalize_invoice_no(value)
      normalize(value)
    end
  end
end
