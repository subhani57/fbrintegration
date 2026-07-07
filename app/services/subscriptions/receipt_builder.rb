# frozen_string_literal: true

module Subscriptions
  class ReceiptBuilder
    class Error < StandardError; end

    ExtraLine = Struct.new(:description, :amount, keyword_init: true)

    def self.call(user:, recorded_by:, months:, monthly_fee:, active_until: nil, extra_lines: [], notes: nil)
      new(
        user: user,
        recorded_by: recorded_by,
        months: months,
        monthly_fee: monthly_fee,
        active_until: active_until,
        extra_lines: extra_lines,
        notes: notes
      ).call
    end

    def initialize(user:, recorded_by:, months:, monthly_fee:, active_until: nil, extra_lines: [], notes: nil)
      @user = user
      @recorded_by = recorded_by
      @months = months.to_i
      @monthly_fee = monthly_fee.to_f
      @active_until = active_until
      @extra_lines = normalize_extra_lines(extra_lines)
      @notes = notes
    end

    def call
      raise Error, 'Months must be at least 1.' if @months < 1
      raise Error, 'Monthly fee cannot be negative.' if @monthly_fee.negative?

      until_date = resolve_active_until
      line_items = build_line_items
      total = line_items.sum { |item| item[:amount].to_f }

      payment = Manager.record_payment!(
        user: @user,
        active_until: until_date,
        recorded_by: @recorded_by,
        amount: total,
        months: @months,
        monthly_fee: @monthly_fee,
        notes: @notes,
        period_months: @months,
        line_items: line_items,
        status: 'pending'
      )

      { payment: payment, total: total, active_until: until_date }
    end

    private

    def resolve_active_until
      return Date.parse(@active_until.to_s) if @active_until.present?

      Manager.extension_base_date(@user) + @months.months
    rescue ArgumentError
      raise Error, 'Please select a valid active-until date.'
    end

    def build_line_items
      items = [
        {
          description: "Subscription (#{@months} month#{'s' if @months != 1})",
          quantity: @months,
          unit_amount: @monthly_fee,
          amount: @months * @monthly_fee,
          position: 0
        }
      ]

      @extra_lines.each_with_index do |line, index|
        items << {
          description: line.description,
          quantity: 1,
          unit_amount: line.amount,
          amount: line.amount,
          position: index + 1
        }
      end

      items
    end

    def normalize_extra_lines(extra_lines)
      extract_extra_line_entries(extra_lines).filter_map do |line|
        data = line.respond_to?(:to_unsafe_h) ? line.to_unsafe_h : line.to_h
        data = data.with_indifferent_access
        description = data[:description].to_s.strip
        amount = data[:amount].to_f
        next if description.blank? && amount.zero?
        raise Error, 'Each additional charge needs a description.' if description.blank?
        raise Error, 'Additional charge amounts cannot be negative.' if amount.negative?

        ExtraLine.new(description: description, amount: amount)
      end
    end

    def extract_extra_line_entries(extra_lines)
      return [] if extra_lines.blank?

      if extra_lines.is_a?(ActionController::Parameters)
        extra_lines.to_unsafe_h.values
      elsif extra_lines.is_a?(Hash)
        extra_lines.values
      else
        Array(extra_lines)
      end
    end
  end
end
