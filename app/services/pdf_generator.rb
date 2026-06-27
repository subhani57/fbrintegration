class PdfGenerator
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

  FOOTER_HEIGHT = 32
  FBR_BRANDING_IMAGE = Rails.root.join('app/assets/images/fbrdigitalinvoicing.png').freeze

  def initialize(invoice)
    @invoice = invoice
    @user = invoice.user
  end

  def generate
    pdf_data = nil

    %i[standard compact ultra].each do |mode|
      @layout = nil
      @density = mode
      pdf_data = build_pdf
      break if pdf_page_count(pdf_data) == 1
    end

    pdf_data
  end

  private

  def build_pdf
    qr_path = nil

    data = Prawn::Document.new(page_size: 'A4', margin: layout[:margin]) do |pdf|
      pdf.font 'Helvetica'
      pdf.fill_color COLORS[:ink]
      pdf.stroke_color COLORS[:line]

      render_header(pdf)
      render_divider(pdf)
      render_parties(pdf)
      render_line_items(pdf)
      qr_path = render_totals_section(pdf)
      render_verification_section(pdf, qr_path)
      render_footer(pdf)
    end.render

    File.delete(qr_path) if qr_path && File.exist?(qr_path)
    data
  end

  def pdf_page_count(data)
    data.scan(%r{/Type /Page\b}).length
  end

  def layout
    @layout ||= build_layout(@density || :standard)
  end

  def build_layout(mode)
    items = @invoice.items.size
    expanded = items <= 4 && mode == :standard

    base = {
      margin: [36, 44, 28, 44],
      gap: expanded ? 16 : 11,
      body: expanded ? 9.5 : 8,
      small: expanded ? 7.5 : 6.5,
      label: expanded ? 8 : 7,
      display: expanded ? 28 : 22,
      table: expanded ? 8.5 : 7.5,
      party_body: expanded ? 11 : 9.5,
      party_header: expanded ? 9.5 : 8.5,
      party_min: expanded ? 92 : 72,
      party_top_margin: expanded ? 20 : 14,
      divider_top_margin: expanded ? 18 : 12,
      logo: expanded ? 56 : 42,
      qr: expanded ? 72 : 54,
      min_item_rows: min_visual_rows(items, mode),
      row_pad: expanded ? [9, 8] : [5, 7]
    }

    case mode
    when :compact
      base.merge!(gap: 9, body: 7.5, table: 7, display: 18, logo: 38, qr: 48,
                  party_body: 9, party_header: 8.5,
                  party_min: 68, party_top_margin: 10, divider_top_margin: 10,
                  min_item_rows: [items + 1, 3].max, row_pad: [4, 6])
    when :ultra
      base.merge!(
        margin: [28, 36, 22, 36], gap: 7, body: 7, small: 6, table: 6.5, display: 16,
        logo: 32, qr: 40, party_body: 8.5, party_header: 8,
        party_min: 62, party_top_margin: 8, divider_top_margin: 8,
        min_item_rows: items + 1, row_pad: [3, 5]
      )
    end

    if items > 6 && mode == :standard
      base.merge!(gap: 9, table: 7.5, min_item_rows: items, row_pad: [4, 6])
    end

    base
  end

  def min_visual_rows(item_count, mode)
    return item_count if mode != :standard || item_count > 6

    case item_count
    when 0 then 4
    when 1 then 5
    when 2 then 5
    when 3 then 4
    when 4 then 4
    else item_count
    end
  end

  def gap(pdf)
    pdf.move_down layout[:gap]
  end

  # ── Header: company left, invoice meta right ──────────────────────────────

  def render_header(pdf)
    w = pdf.bounds.width
    left_w = w * 0.52
    right_w = w - left_w

    right_html = [
      "<color rgb='#{COLORS[:accent]}'>SALES TAX INVOICE</color>",
      "<color rgb='#{COLORS[:muted]}'>Invoice No.:</color> <b>#{escape_html(@invoice.pdf_display_number)}</b>",
      "<color rgb='#{COLORS[:muted]}'>Date:</color> <b>#{@invoice.invoice_date.strftime('%d %b %Y')}</b>",
      "<color rgb='#{COLORS[:muted]}'>Type:</color> <b>#{escape_html(@invoice.invoice_type)}</b>",
      "<color rgb='#{COLORS[:muted]}'>FBR No.:</color> <b>#{escape_html(@invoice.fbr_invoice_id.presence || 'Pending')}</b>"
    ].join("\n")

    if company_logo_path
      pdf.table([
        [{ image: company_logo_path, fit: [layout[:logo], layout[:logo]], position: :left, vposition: :top,
           borders: [], padding: [0, 10, 0, 0] },
         { content: right_html, inline_format: true, align: :right, size: layout[:body],
           leading: 5, borders: [], padding: [0, 0, 0, 8], valign: :top }]
      ], column_widths: [layout[:logo] + 10, w - layout[:logo] - 10], width: w, cell_style: { borders: [] })
    else
      pdf.table([
        [{ content: right_html, inline_format: true, align: :right, size: layout[:body],
           leading: 5, borders: [], padding: [0, 0, 0, 0], colspan: 2 }]
      ], column_widths: [left_w, right_w], width: w, cell_style: { borders: [] })
    end
  end

  def render_divider(pdf)
    pdf.move_down layout[:divider_top_margin]
    y = pdf.cursor
    pdf.stroke_color COLORS[:accent]
    pdf.line_width = 2
    pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.left + 72, at: y
    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.5
    pdf.stroke_horizontal_line pdf.bounds.left + 80, pdf.bounds.right, at: y
    pdf.line_width = 1
    pdf.move_down 14
  end

  # ── Parties as side-by-side cards ───────────────────────────────────────────

  def render_parties(pdf)
    pdf.move_down layout[:party_top_margin]
    w = pdf.bounds.width
    party_gap = 14
    box_w = (w - party_gap) / 2.0

    pdf.table([
      [party_header_cell('Sender Information'), party_spacer_cell, party_header_cell('Buyer Information')],
      [party_body_cell(seller_fields), party_spacer_cell, party_body_cell(buyer_fields)]
    ], column_widths: [box_w, party_gap, box_w], width: w,
       cell_style: { border_color: COLORS[:line], border_width: 0.75 }) do |t|
      t.row(0).background_color = COLORS[:accent]
      t.row(0).text_color = COLORS[:white]
      t.row(0).font_style = :bold
      t.row(0).size = layout[:party_header]
      t.row(0).padding = [10, 14]
      t.row(0).borders = [:top, :left, :right]

      t.row(1).background_color = COLORS[:white]
      t.row(1).padding = [16, 16]
      t.row(1).height = layout[:party_min]
      t.row(1).valign = :top
      t.row(1).borders = [:bottom, :left, :right]

      t.columns(0).padding = [9, 8, 14, 14]
      t.columns(2).padding = [9, 14, 14, 8]

      t.column(1).borders = []
      t.column(1).background_color = COLORS[:white]
      t.column(1).padding = [0, 0]
    end

    gap(pdf)
  end

  def party_spacer_cell
    { content: '', borders: [], background_color: COLORS[:white], padding: [0, 0] }
  end

  def party_header_cell(title)
    { content: title, borders: [:top, :left, :right] }
  end

  def party_body_cell(fields)
    {
      content: party_body_html(fields),
      inline_format: true,
      size: layout[:party_body],
      leading: 6
    }
  end

  def party_body_html(fields)
    body_size = layout[:party_body]
    name_size = body_size.to_i + 2
    lines = ["<font size='#{name_size}'><b><color rgb='#{COLORS[:ink]}'>#{escape_html(fields[:name].presence || '—')}</color></b></font>"]

    lines << party_detail_row('NTN/CNIC', fields[:ntn])

    if fields[:address].present?
      lines << "<color rgb='#{COLORS[:muted]}'>#{escape_html(fields[:address])}</color>"
    end

    lines << party_detail_row('Province', fields[:province]) if fields.fetch(:show_province, true)
    lines << party_detail_row('Registration', fields[:extra]) if fields[:extra].present?

    lines.join("\n")
  end

  def party_detail_row(label, value)
    val = escape_html(value.presence || '—')
    "<color rgb='#{COLORS[:muted]}'>#{escape_html(label)}</color>     <b><color rgb='#{COLORS[:ink]}'>#{val}</color></b>"
  end

  # ── Line items ──────────────────────────────────────────────────────────────

  def render_line_items(pdf)
    w = pdf.bounds.width

    pdf.fill_color COLORS[:muted]
    pdf.text 'Line Items', size: layout[:label], style: :bold
    pdf.fill_color COLORS[:ink]
    pdf.move_down 6

    pdf.table(build_item_rows, width: w, header: true,
             cell_style: {
               size: layout[:table],
               padding: layout[:row_pad],
               border_color: COLORS[:line],
               text_color: COLORS[:ink],
               overflow: :shrink_to_fit,
               valign: :center
             }) do |t|
      t.row(0).background_color = COLORS[:wash]
      t.row(0).font_style = :bold
      t.row(0).text_color = COLORS[:ink]
      t.row(0).size = layout[:label]
      t.row(0).borders = [:bottom]
      t.row(0).border_bottom_color = COLORS[:accent]
      t.row(0).border_bottom_width = 1.5
      t.row(0).padding = [7, 8]

      t.columns(0).width = 24
      t.columns(0).align = :center
      t.columns(2).width = 52
      t.columns(3).width = 46
      t.columns(3).align = :right
      t.columns(3).overflow = :truncate
      t.columns(4).width = 56
      t.columns(4).align = :center
      t.columns(5).width = 46
      t.columns(5).align = :right
      t.columns(5).overflow = :truncate
      t.columns(6..8).align = :right

      t.rows(1..-1).borders = [:bottom]
      t.rows(1..-1).border_bottom_width = 0.5
    end

    gap(pdf)
  end

  def build_item_rows
    header = ['#', 'Description', 'HS Code', 'Qty', 'UoM', 'Rate', 'Excl. ST', 'Tax', 'Amount']
    rows = [header]

    @invoice.items.each_with_index do |item, i|
      excl = line_exclusive(item)
      tax = line_tax(item)

      rows << [
        (i + 1).to_s,
        safe_text(item.description),
        safe_text(item.hs_code),
        format_qty(item.quantity),
        safe_text(item.uom),
        "#{format_qty(item.tax_rate)}%",
        format_currency(excl),
        format_currency(tax),
        format_currency(excl + tax)
      ]
    end

    filler = layout[:min_item_rows] - @invoice.items.size
    filler.times { rows << ['', '', '', '', '', '', '', '', ''] }

    rows
  end

  # ── Totals + QR + compliance ────────────────────────────────────────────────

  def render_totals_section(pdf)
    w = pdf.bounds.width
    qr_path = generate_qr_png

    exclusive = @invoice.items.sum { |i| line_exclusive(i) }
    tax = @invoice.items.sum { |i| line_tax(i) }
    grand = @invoice.total_amount.to_f.nonzero? || (exclusive + tax)

    totals_w = 210
    left_w = w - totals_w

    compliance = '<b>FBR Digital Invoicing</b>'
    compliance += "\nOfficial computer-generated sales tax invoice."
    compliance += "\nVerify at iris.fbr.gov.pk"
    compliance += "\nSubmitted: #{@invoice.submitted_at.strftime('%d %b %Y, %I:%M %p')}" if @invoice.submitted_at.present?
    compliance += "\n<b>FBR #: #{escape_html(@invoice.fbr_invoice_id)}</b>" if @invoice.fbr_invoice_id.present?

    totals_table = pdf.make_table([
      [
        { content: 'Subtotal', text_color: COLORS[:muted], borders: [] },
        { content: format_currency(exclusive), align: :right, borders: [] }
      ],
      [
        { content: 'Sales tax', text_color: COLORS[:muted], borders: [] },
        { content: format_currency(tax), align: :right, borders: [] }
      ],
      [
        { content: 'Amount due', font_style: :bold, borders: [] },
        { content: format_currency(grand), align: :right, font_style: :bold,
          text_color: COLORS[:accent], borders: [] }
      ]
    ], width: totals_w, cell_style: { padding: [4, 4], size: layout[:body], borders: [] }) do |t|
      t.row(2).borders = [:top]
      t.row(2).border_top_color = COLORS[:line]
      t.row(2).padding = [7, 4, 2, 4]
    end

    pdf.table([
      [
        { content: compliance, inline_format: true, size: layout[:small], leading: 3.5,
          background_color: COLORS[:wash], padding: [10, 12], borders: [:top, :bottom, :left],
          valign: :center },
        { content: totals_table, padding: [8, 10], borders: [:top, :bottom, :right] }
      ]
    ], column_widths: [left_w, totals_w], width: w) do |t|
      t.cells.border_color = COLORS[:line]
      t.cells.border_width = 0.75
    end

    gap(pdf)
    qr_path
  end

  def render_verification_section(pdf, qr_path)
    qr_size = layout[:qr]
    image_w = qr_size + 24
    block_w = image_w * 2

    fbr_cell = {
      image: fbr_branding_image_path,
      fit: [qr_size, qr_size],
      position: :center,
      vposition: :center,
      borders: [:top, :bottom, :left],
      padding: [10, 8],
      background_color: COLORS[:wash]
    }

    qr_cell = if qr_path && File.exist?(qr_path)
                { image: qr_path, fit: [qr_size, qr_size], position: :center, vposition: :center,
                  borders: [:top, :bottom, :right], padding: [10, 8], background_color: COLORS[:wash] }
              else
                { content: "<color rgb='#{COLORS[:muted]}'><b>QR Code</b>\nVerify with FBR</color>",
                  inline_format: true, align: :center, valign: :center, borders: [:top, :bottom, :right],
                  padding: [10, 8], background_color: COLORS[:wash] }
              end

    panel_h = qr_size + 24

    pdf.table([[fbr_cell, qr_cell]],
              column_widths: [image_w, image_w],
              width: block_w,
              position: :right) do |t|
      t.cells.border_color = COLORS[:line]
      t.cells.border_width = 0.75
      t.row(0).height = panel_h
    end

    gap(pdf)
  end

  def render_footer(pdf)
    footer_top = pdf.bounds.bottom + FOOTER_HEIGHT
    space = pdf.cursor - footer_top
    pdf.move_down [space - 6, 0].max if space > 10

    pdf.stroke_color COLORS[:line]
    pdf.line_width = 0.5
    pdf.stroke_horizontal_rule
    pdf.move_down 8

    pdf.fill_color COLORS[:muted]
    pdf.text 'Thank you for your business · Computer-generated document — no signature required',
             align: :center, size: layout[:small]
    pdf.fill_color COLORS[:ink]
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  def seller_fields
    party_fields(
      name: @invoice.seller_name.presence || @user.business_name,
      address: @invoice.seller_address.presence || @user.address,
      ntn: @invoice.seller_ntn.presence || @user.ntn_cnic,
      province: @invoice.seller_province,
      extra: nil
    )
  end

  def buyer_fields
    party_fields(
      name: @invoice.buyer_name,
      address: @invoice.buyer_address,
      ntn: @invoice.buyer_ntn,
      province: @invoice.buyer_province,
      extra: @invoice.buyer_registration_type,
      show_province: false
    )
  end

  def generate_qr_png
    fbr_qr = @invoice.fbr_qr_image_base64
    if fbr_qr.present?
      path = Rails.root.join("tmp/fbr_qr_#{@invoice.id}_#{Process.pid}.png")
      File.binwrite(path, Base64.decode64(fbr_qr.to_s.gsub(/\s+/, '')))
      return path.to_s if File.size?(path)
    end

    return nil unless @invoice.fbr_invoice_id.present?

    qr_data = {
      ver: '1.0',
      seller_ntn: @user.ntn_cnic || '0000000000000',
      buyer_ntn: @invoice.buyer_ntn || '0000000000000',
      inv_num: @invoice.fbr_invoice_id,
      inv_date: @invoice.invoice_date.iso8601,
      total_amount: @invoice.total_amount.to_s,
      tax_amount: @invoice.tax_amount.to_s
    }.to_json

    path = Rails.root.join("tmp/qr_invoice_#{@invoice.id}_#{Process.pid}.png")
    qr = RQRCode::QRCode.new(qr_data)
    File.binwrite(path, qr.as_png(size: 240, border_modules: 1).to_s)
    path.to_s
  rescue StandardError => e
    AppLogger.error('pdf.qr_generation_failed', exception: e, invoice_id: @invoice.id)
    nil
  end

  def company_logo_path
    return unless @user.company_logo.present?

    path = @user.company_logo.path
    File.exist?(path) ? path : nil
  end

  def fbr_branding_image_path
    FBR_BRANDING_IMAGE.to_s if File.exist?(FBR_BRANDING_IMAGE)
  end

  def party_fields(name:, address:, ntn:, province:, extra:, show_province: true)
    { name: name, address: address, ntn: ntn, province: province, extra: extra, show_province: show_province }
  end

  def line_exclusive(item)
    val = item.total_value.to_f
    val.nonzero? ? val : (item.quantity.to_f * item.unit_price.to_f)
  end

  def line_tax(item)
    excl = line_exclusive(item)
    val = item.sales_tax.to_f
    val.nonzero? ? val : (excl * item.tax_rate.to_f / 100.0)
  end

  def format_currency(amount)
    formatted = format('%.2f', amount.to_f)
    "Rs. #{formatted.gsub(/(\d)(?=(\d{3})+\.)/, '\\1,')}"
  end

  def format_qty(value)
    format('%.2f', value.to_f).sub(/\.?0+$/, '')
  end

  def safe_text(text)
    text.to_s.gsub(/[\r\n]+/, ' ').strip
  end

  def escape_html(text)
    safe_text(text).gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end
end
