# frozen_string_literal: true

module HsCodeSorting
  module_function

  def sort_key(code)
    code.to_s.scan(/\d+/).map(&:to_i)
  end

  def sort_codes(codes)
    codes.sort_by { |item| sort_key(item[:code] || item['code']) }
  end
end
