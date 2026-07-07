# frozen_string_literal: true

module Subscriptions
  class ReceiptGenerator
    Prawn::Fonts::AFM.hide_m17n_warning = true if defined?(Prawn::Fonts::AFM)

    COLORS = {
      ink: '0F172A',
      accent: '1D4ED8',
      accent_light: 'DBEAFE',
      muted: '64748B',
      line: 'E2E8F0',
      wash: 'F8FAFC',
      white: 'FFFFFF'
    }.freeze

    LOGO_PATH = Rails.root.join('app/assets/images/logo.png').freeze

    def initialize(payment)
      @payment = payment
      @user = payment.user
      @line_items = payment.line_items.to_a
    end

    def filename
      "receipt-#{@payment.receipt_number}.pdf"
    end

    def content_type
      'application/pdf'
    end

    def to_pdf
      Prawn::Document.new(page_size: 'A4', margin: [40, 48, 40, 48]) do |pdf|
        pdf.font 'Helvetica'
        pdf.fill_color COLORS[:ink]
        pdf.stroke_color COLORS[:line]

        render_header(pdf)
        render_divider(pdf)
        render_receipt_meta(pdf)
        render_taxpayer_details(pdf)
        render_line_items(pdf)
        render_total(pdf)
        render_footer(pdf)
      end.render
    end

    def to_text
      lines = []
      lines << "#{Branding::APP_NAME} — Payment Receipt"
      lines << "Receipt #: #{@payment.receipt_number}"
      lines << "Date: #{@payment.created_at.strftime('%d %B %Y')}"
      lines << "Taxpayer: #{@user.email}"
      lines << "Business: #{@user.business_name}" if @user.business_name.present?
      lines << ''
      lines << 'Charges:'
      charge_rows.each do |row|
        lines << charge_row_text(row)
      end
      lines << ''
      lines << "Total: Rs. #{format_amount(@payment.amount)}"
      lines << "Active until: #{@payment.active_until.strftime('%d %B %Y')}"
      lines << "Notes: #{@payment.notes.presence || '—'}"
      lines.join("\n")
    end

    private

    def render_header(pdf)
      w = pdf.bounds.width
      logo_w = 88

      if logo_path
        pdf.table([
          [
            { image: logo_path, fit: [logo_w, logo_w], position: :left, vposition: :top,
              borders: [], padding: [0, 16, 0, 0] },
            { content: header_text, inline_format: true, align: :right, size: 10, leading: 5,
              borders: [], padding: [4, 0, 0, 0], valign: :top }
          ]
        ], column_widths: [logo_w + 16, w - logo_w - 16], width: w, cell_style: { borders: [] })
      else
        pdf.text header_text, inline_format: true, align: :right, size: 10, leading: 5
      end

      pdf.move_down 18
      pdf.fill_color COLORS[:accent]
      title = @payment.pending? ? 'PAYMENT RECEIPT (UNPAID)' : 'PAYMENT RECEIPT'
      pdf.text title, size: 22, style: :bold, align: :left
      pdf.fill_color COLORS[:ink]
    end

    def header_text
      [
        "<color rgb='#{COLORS[:ink]}'><b>#{escape_html(Branding::COMPANY_NAME)}</b></color>",
        "<color rgb='#{COLORS[:muted]}'>#{escape_html(Branding::PRODUCT_NAME)}</color>",
        "<color rgb='#{COLORS[:muted]}'>#{escape_html(Branding::SUPPORT_EMAIL)}</color>"
      ].join("\n")
    end

    def render_divider(pdf)
      y = pdf.cursor
      pdf.stroke_color COLORS[:accent]
      pdf.line_width = 2
      pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.left + 72, at: y
      pdf.stroke_color COLORS[:line]
      pdf.line_width = 0.5
      pdf.stroke_horizontal_line pdf.bounds.left + 80, pdf.bounds.right, at: y
      pdf.line_width = 1
      pdf.move_down 18
    end

    def render_receipt_meta(pdf)
      w = pdf.bounds.width
      left_w = w * 0.5
      right_w = w - left_w

      left = [
        "<color rgb='#{COLORS[:muted]}'>Receipt #</color>",
        "<b>#{escape_html(@payment.receipt_number)}</b>",
        '',
        "<color rgb='#{COLORS[:muted]}'>Payment date</color>",
        "<b>#{@payment.created_at.strftime('%d %B %Y')}</b>",
        '',
        "<color rgb='#{COLORS[:muted]}'>Status</color>",
        payment_status_text
      ].join("\n")

      right = [
        "<color rgb='#{COLORS[:muted]}'>Active until</color>",
        "<b>#{@payment.active_until.strftime('%d %B %Y')}</b>"
      ]
      if @payment.months.present? && @payment.monthly_fee.present?
        right << ''
        right << "<color rgb='#{COLORS[:muted]}'>Subscription</color>"
        right << "<b>#{@payment.months} month#{'s' if @payment.months != 1} × #{format_currency(@payment.monthly_fee)}</b>"
      end

      right = right.join("\n")

      pdf.table([
        [
          { content: left, inline_format: true, size: 10, leading: 5, borders: [], padding: [12, 14] },
          { content: right, inline_format: true, size: 10, leading: 5, borders: [], padding: [12, 14] }
        ]
      ], column_widths: [left_w, right_w], width: w) do |t|
        t.cells.background_color = COLORS[:wash]
        t.cells.border_color = COLORS[:line]
        t.cells.border_width = 0.75
      end

      pdf.move_down 16
    end

    def render_taxpayer_details(pdf)
      pdf.fill_color COLORS[:muted]
      pdf.text 'BILLED TO', size: 8, style: :bold
      pdf.fill_color COLORS[:ink]
      pdf.move_down 6

      w = pdf.bounds.width
      rows = [
        ['Business', @user.business_name.presence || '—'],
        ['Email', @user.email],
        ['NTN/CNIC', @user.ntn_cnic.presence || '—'],
        ['Phone', @user.phone.presence || '—'],
        ['Address', @user.address.presence || '—']
      ]

      pdf.table(rows, width: w, column_widths: [110, w - 110],
                cell_style: { size: 9.5, padding: [7, 10], border_color: COLORS[:line], borders: [:bottom] }) do |t|
        t.columns(0).font_style = :bold
        t.columns(0).text_color = COLORS[:muted]
        t.columns(0).background_color = COLORS[:wash]
        t.columns(1).font_style = :bold
      end

      pdf.move_down 18
    end

    def render_line_items(pdf)
      pdf.fill_color COLORS[:muted]
      pdf.text 'CHARGES', size: 8, style: :bold
      pdf.fill_color COLORS[:ink]
      pdf.move_down 6

      w = pdf.bounds.width
      rows = [['Description', 'Qty', 'Rate', 'Amount']]
      charge_rows.each do |row|
        rows << [
          row[:description],
          row[:quantity],
          row[:rate],
          row[:amount]
        ]
      end

      pdf.table(rows, width: w, header: true,
                column_widths: [w * 0.48, w * 0.12, w * 0.20, w * 0.20],
                cell_style: { size: 9.5, padding: [8, 10], border_color: COLORS[:line], valign: :center, overflow: :expand }) do |t|
        t.row(0).background_color = COLORS[:accent]
        t.row(0).text_color = COLORS[:white]
        t.row(0).font_style = :bold
        t.row(0).size = 9
        t.row(0).borders = [:bottom]
        t.row(0).border_bottom_width = 1.5
        t.columns(1..3).align = :right
        t.rows(1..-1).borders = [:bottom]
        t.rows(1..-1).border_bottom_width = 0.5
      end

      pdf.move_down 12
    end

    def render_total(pdf)
      w = pdf.bounds.width
      totals_w = 220
      left_w = w - totals_w

      notes = @payment.notes.presence || 'Thank you for your payment.'
      notes_block = "<color rgb='#{COLORS[:muted]}'>Notes</color>\n<b>#{escape_html(notes)}</b>"

      totals = pdf.make_table([
        [
          { content: 'Subtotal', text_color: COLORS[:muted], borders: [] },
          { content: format_currency(@payment.amount), align: :right, borders: [] }
        ],
        [
          { content: 'Total paid', font_style: :bold, borders: [] },
          { content: format_currency(@payment.amount), align: :right, font_style: :bold,
            text_color: COLORS[:accent], borders: [] }
        ]
      ], width: totals_w, cell_style: { padding: [5, 4], size: 10, borders: [] }) do |t|
        t.row(1).borders = [:top]
        t.row(1).border_top_color = COLORS[:line]
        t.row(1).padding = [8, 4, 2, 4]
      end

      pdf.table([
        [
          { content: notes_block, inline_format: true, size: 9.5, leading: 4,
            background_color: COLORS[:wash], padding: [12, 14], borders: [:top, :bottom, :left],
            valign: :center },
          { content: totals, padding: [10, 12], borders: [:top, :bottom, :right] }
        ]
      ], column_widths: [left_w, totals_w], width: w) do |t|
        t.cells.border_color = COLORS[:line]
        t.cells.border_width = 0.75
      end
    end

    def render_footer(pdf)
      pdf.move_down 28
      pdf.stroke_color COLORS[:line]
      pdf.line_width = 0.5
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      pdf.fill_color COLORS[:muted]
      pdf.text "#{Branding::FOOTER_LINE} · Official payment receipt — no signature required",
               align: :center, size: 8
      pdf.fill_color COLORS[:ink]
    end

    def charge_rows
      if @line_items.any?
        @line_items.map { |item| charge_row_from_item(item) }
      else
        [legacy_charge_row]
      end
    end

    def charge_row_from_item(item)
      qty = item.quantity.to_f
      unit = item.unit_amount.to_f
      {
        description: item.description,
        quantity: qty > 1 ? format_qty(qty) : '1',
        rate: unit.positive? ? format_currency(unit) : '—',
        amount: format_currency(item.amount)
      }
    end

    def legacy_charge_row
      if @payment.months.present? && @payment.monthly_fee.present?
        {
          description: "Subscription (#{@payment.months} month#{'s' if @payment.months != 1})",
          quantity: @payment.months.to_s,
          rate: format_currency(@payment.monthly_fee),
          amount: format_currency(@payment.months * @payment.monthly_fee)
        }
      else
        {
          description: 'Subscription payment',
          quantity: '1',
          rate: format_currency(@payment.amount),
          amount: format_currency(@payment.amount)
        }
      end
    end

    def charge_row_text(row)
      if row[:quantity].to_s != '1' && row[:rate] != '—'
        "  • #{row[:description]}: #{row[:quantity]} × #{row[:rate]} = #{row[:amount]}"
      else
        "  • #{row[:description]}: #{row[:amount]}"
      end
    end

    def payment_status_text
      if @payment.paid?
        paid_on = @payment.paid_at&.strftime('%d %B %Y') || @payment.created_at.strftime('%d %B %Y')
        "<b><color rgb='16A34A'>PAID</color></b> · #{paid_on}"
      else
        "<b><color rgb='DC2626'>UNPAID</color></b> · payment pending"
      end
    end

    def logo_path
      LOGO_PATH.to_s if File.exist?(LOGO_PATH)
    end

    def format_currency(amount)
      formatted = format('%.2f', amount.to_f)
      "Rs. #{formatted.gsub(/(\d)(?=(\d{3})+\.)/, '\\1,')}"
    end

    def format_amount(amount)
      format('%.2f', amount.to_f)
    end

    def format_qty(value)
      format('%.2f', value.to_f).sub(/\.?0+$/, '')
    end

    def escape_html(text)
      text.to_s.gsub(/[\r\n]+/, ' ').strip
            .gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end
  end
end
