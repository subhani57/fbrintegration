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

  PARTY_SUBTITLES = {
    seller: 'Your business',
    buyer: 'Customer / buyer'
  }.freeze

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
      party_body: expanded ? 10.5 : 9.5,
      party_header: expanded ? 9.5 : 9,
      party_label: expanded ? 8.5 : 8,
      party_top_margin: expanded ? 18 : 14,
      party_gap: expanded ? 24 : 20,
      party_pad: expanded ? [24, 24, 24, 24] : [20, 20, 20, 20],
      party_header_pad: expanded ? [12, 24, 12, 24] : [10, 20, 10, 20],
      party_field_gap: expanded ? 2 : 1.5,
      party_label_top: expanded ? 9 : 8,
      party_address_leading: expanded ? 2 : 1.5,
      divider_top_margin: expanded ? 16 : 11,
      logo: expanded ? 100 : 80,
      qr: expanded ? 72 : 54,
      min_item_rows: min_visual_rows(items, mode),
      row_pad: expanded ? [9, 8] : [5, 7]
    }

    case mode
    when :compact
      base.merge!(gap: 9, body: 7.5, table: 7, display: 18, logo: 68, qr: 48,
                  party_body: 9, party_header: 8.5, party_label: 7.5,
                  party_top_margin: 10, divider_top_margin: 9,
                  party_gap: 18, party_pad: [16, 16, 16, 16], party_header_pad: [10, 16, 10, 16],
                  party_field_gap: 1.5, party_label_top: 7, party_address_leading: 1.5,
                  min_item_rows: [items + 1, 3].max, row_pad: [4, 6])
    when :ultra
      base.merge!(
        margin: [28, 36, 22, 36], gap: 7, body: 7, small: 6, table: 6.5, display: 16,
        logo: 56, qr: 40, party_body: 8.5, party_header: 8, party_label: 7,
        party_top_margin: 8, divider_top_margin: 7,
        party_gap: 14, party_pad: [14, 14, 14, 14], party_header_pad: [9, 14, 9, 14],
        party_field_gap: 1, party_label_top: 5, party_address_leading: 1,
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
      "<color rgb='#{COLORS[:muted]}'>Digital Invoice No.:</color> <b>#{escape_html(@invoice.fbr_invoice_id.presence || 'Pending')}</b>",
      "<color rgb='#{COLORS[:muted]}'>Date:</color> <b>#{@invoice.invoice_date.strftime('%d %b %Y')}</b>",
      "<color rgb='#{COLORS[:muted]}'>Type:</color> <b>#{escape_html(@invoice.invoice_type)}</b>",
      "<color rgb='#{COLORS[:muted]}'>Invoice No.:</color> <b>#{escape_html(@invoice.pdf_display_number)}</b>"
    ]
    if @invoice.po_number.present?
      right_html << "<color rgb='#{COLORS[:muted]}'>PO #:</color> <b>#{escape_html(@invoice.po_number)}</b>"
    end
    right_html = right_html.join("\n")

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
    party_gap = layout[:party_gap]
    box_w = (w - party_gap) / 2.0
    pad = layout[:party_pad]
    header_pad = layout[:party_header_pad]

    rows = [[
      party_header_cell('Sender Information', :seller),
      party_spacer_cell,
      party_header_cell('Buyer Information', :buyer)
    ]]

    aligned_party_body_rows(seller_fields, buyer_fields, pad).each do |left, right|
      rows << [left, party_spacer_cell, right]
    end

    pdf.table(rows, column_widths: [box_w, party_gap, box_w], width: w,
              cell_style: { border_color: COLORS[:line], border_width: 0.75 }) do |t|
      t.row(0).text_color = COLORS[:white]
      t.row(0).padding = header_pad
      t.row(0).borders = [:top, :left, :right]
      t.row(0).valign = :center
      t.columns(0).row(0).background_color = COLORS[:accent]
      t.columns(2).row(0).background_color = COLORS[:accent]

      last = t.row_length - 1
      (1..last).each do |i|
        row_pad = party_body_row_pad(i, last, pad)
        t.row(i).padding = [0, 0, 0, 0]
        t.row(i).valign = :top
        t.columns(0).row(i).padding = row_pad
        t.columns(2).row(i).padding = row_pad
        t.columns(0).row(i).background_color = COLORS[:accent_light]
        t.columns(2).row(i).background_color = COLORS[:accent_light]
        t.columns(0).row(i).borders = i == last ? [:bottom, :left] : [:left]
        t.columns(2).row(i).borders = i == last ? [:bottom, :right] : [:right]
        t.column(1).row(i).borders = []
        t.column(1).row(i).background_color = COLORS[:white]
        t.column(1).row(i).padding = [0, 0]
      end
    end

    gap(pdf)
  end

  def party_body_row_pad(index, last_index, pad)
    top = index == 1 ? pad[0] : 0
    bottom = index == last_index ? pad[2] : 0
    [top, pad[1], bottom, pad[3]]
  end

  def aligned_party_body_rows(seller, buyer, _pad)
    body = layout[:party_body]
    label = layout[:party_label]
    field_gap = layout[:party_field_gap]
    label_top = layout[:party_label_top]
    address_leading = layout[:party_address_leading]

    rows = [
      [
        party_value_cell(seller[:name], size: body + 2, font_style: :bold),
        party_value_cell(buyer[:name], size: body + 2, font_style: :bold)
      ],
      [party_gap_cell(label_top), party_gap_cell(label_top)],
      [
        party_label_cell('NTN/CNIC', label, field_gap),
        party_label_cell('NTN/CNIC', label, field_gap)
      ],
      [
        party_value_cell(seller[:ntn], size: body, font_style: :bold),
        party_value_cell(buyer[:ntn], size: body, font_style: :bold)
      ],
      [party_gap_cell(label_top), party_gap_cell(label_top)],
      [
        party_label_cell('Address', label, field_gap),
        party_label_cell('Address', label, field_gap)
      ],
      [
        party_value_cell(seller[:address], size: body, leading: address_leading),
        party_value_cell(buyer[:address], size: body, leading: address_leading)
      ]
    ]

    if seller.fetch(:show_province, true) || buyer.fetch(:show_province, true)
      rows << [party_gap_cell(label_top), party_gap_cell(label_top)]
      rows << [
        party_label_cell('Province', label, field_gap),
        party_label_cell('Province', label, field_gap)
      ]
      rows << [
        party_value_cell(seller[:province], size: body, font_style: :bold),
        party_value_cell(buyer[:province], size: body, font_style: :bold)
      ]
    end

    rows
  end

  def party_label_cell(text, size, bottom_gap)
    {
      content: text, size: size, font_style: :italic, text_color: COLORS[:muted],
      padding: [0, 0, bottom_gap, 0], borders: [], border_width: 0
    }
  end

  def party_value_cell(value, size:, font_style: nil, leading: nil, padding: [0, 0, 0, 0])
    cell = {
      content: value.presence || '—',
      size: size,
      text_color: COLORS[:ink],
      padding: padding,
      borders: [],
      border_width: 0
    }
    cell[:font_style] = font_style if font_style
    cell[:leading] = leading if leading
    cell
  end

  def party_gap_cell(height)
    { content: '', height: height, padding: [0, 0, 0, 0], borders: [], border_width: 0 }
  end

  def party_spacer_cell
    { content: '', borders: [], background_color: COLORS[:white], padding: [0, 0] }
  end

  def party_header_cell(title, variant)
    header_size = layout[:party_header]
    subtitle_size = [header_size - 1.5, 6.5].max
    subtitle = PARTY_SUBTITLES.fetch(variant)

    content = [
      "<font name='Helvetica-Bold' size='#{header_size}'><b>#{escape_html(title).upcase}</b></font>",
      "<font name='Helvetica' size='#{subtitle_size}'><color rgb='DBEAFE'>#{subtitle}</color></font>"
    ].join("\n")

    { content: content, inline_format: true, leading: 4, borders: [:top, :left, :right], align: :left }
  end

  # ── Line items ──────────────────────────────────────────────────────────────

  def render_line_items(pdf)
    w = pdf.bounds.width
    rows = build_item_rows
    column_widths = item_table_column_widths(pdf, rows, w)

    pdf.fill_color COLORS[:muted]
    pdf.text 'Line Items', size: layout[:label], style: :bold
    pdf.fill_color COLORS[:ink]
    pdf.move_down 6

    pdf.table(rows, width: w, column_widths: column_widths, header: true,
             cell_style: {
               size: layout[:table],
               padding: layout[:row_pad],
               border_color: COLORS[:line],
               text_color: COLORS[:ink],
               overflow: :truncate,
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

      t.columns(0).align = :center
      t.columns(3).align = :right
      t.columns(4).align = :center
      t.columns(5).align = :right
      t.columns(6..8).align = :right

      t.rows(1..-1).borders = [:bottom]
      t.rows(1..-1).border_bottom_width = 0.5
    end

    gap(pdf)
  end

  def item_table_column_widths(pdf, rows, table_width)
    body_size = layout[:table]
    header_size = layout[:label]
    horizontal_pad = (layout[:row_pad][1] * 2) + 8

    constraints = [
      { min: 20, max: 30 },    # #
      { min: 72, max: nil },     # Description — absorbs extra table width
      { min: 52, max: 96 },      # HS Code
      { min: 30, max: 52 },      # Qty
      { min: 36, max: 96 },      # UoM
      { min: 36, max: 56 },      # Rate
      { min: 44, max: 88 },      # Excl ST
      { min: 44, max: 88 },      # Tax
      { min: 44, max: 88 }       # Amount
    ]

    widths = constraints.size.times.map do |col|
      content_width = rows.each_with_index.filter_map do |row, row_idx|
        text = row[col].to_s
        next if text.blank?

        size = row_idx.zero? ? header_size : body_size
        style = row_idx.zero? ? :bold : :normal
        pdf.width_of(text, size: size, style: style)
      end.max.to_f

      natural = content_width + horizontal_pad
      natural = [natural, constraints[col][:min]].max
      natural = [natural, constraints[col][:max]].min if constraints[col][:max]
      natural
    end

    fixed_width = widths.each_with_index.sum { |width, idx| idx == 1 ? 0 : width }
    available_desc = table_width - fixed_width
    widths[1] = [[widths[1], available_desc].min, constraints[1][:min]].max

    if widths.sum > table_width
      overflow = widths.sum - table_width
      slack = widths.each_with_index.sum do |width, idx|
        next 0 if idx == 1

        width - constraints[idx][:min]
      end

      if slack.positive?
        widths.each_with_index do |width, idx|
          next if idx == 1

          reduction = overflow * ((width - constraints[idx][:min]) / slack)
          widths[idx] = [width - reduction, constraints[idx][:min]].max
        end
      end

      widths[1] = table_width - widths.each_with_index.sum { |width, idx| idx == 1 ? 0 : width }
    elsif widths.sum < table_width
      widths[1] += table_width - widths.sum
    end

    widths
  end

  def build_item_rows
    header = ['#', 'Description', 'HS Code', 'Qty', 'UoM', 'Rate', 'Excl ST', 'Tax', 'Amount']
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
        format_line_amount(excl),
        format_line_amount(tax),
        format_line_amount(excl + tax)
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
    compliance += "\n<b>Digital Invoice No.: #{escape_html(@invoice.fbr_invoice_id)}</b>" if @invoice.fbr_invoice_id.present?

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
      name: format_party_name(@user.business_name.presence || @user.email),
      address: @user.address,
      ntn: @user.ntn_cnic,
      province: @user.seller_province
    )
  end

  def buyer_fields
    party_fields(
      name: format_party_name(@invoice.buyer_name),
      address: @invoice.buyer_address,
      ntn: @invoice.buyer_ntn,
      province: @invoice.buyer_province,
      show_province: true
    )
  end

  def format_party_name(value)
    text = value.to_s.strip
    return text if text.blank? || text.include?('@')

    text.titleize
  end

  def generate_qr_png
    fbr_qr = @invoice.fbr_qr_image_base64
    if fbr_qr.present?
      path = Rails.root.join("tmp/fbr_qr_#{@invoice.id}_#{Process.pid}.png")
      File.binwrite(path, Base64.decode64(fbr_qr.to_s.gsub(/\s+/, '')))
      return path.to_s if File.size?(path)
    end

    return nil unless @invoice.fbr_invoice_id.present?

    path = Rails.root.join("tmp/qr_invoice_#{@invoice.id}_#{Process.pid}.png")
    qr = RQRCode::QRCode.new(@invoice.fbr_invoice_id)
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

  def party_fields(name:, address:, ntn:, province:, show_province: true)
    { name: name, address: address, ntn: ntn, province: province, show_province: show_province }
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

  def format_line_amount(amount)
    formatted = format('%.2f', amount.to_f).sub(/\.?0+$/, '')
    parts = formatted.split('.')
    parts[0] = parts[0].gsub(/\B(?=(\d{3})+(?!\d))/, ',')
    parts.join('.')
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
