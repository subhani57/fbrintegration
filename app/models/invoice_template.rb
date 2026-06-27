# frozen_string_literal: true

class InvoiceTemplate < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(:name) }

  def apply_to_invoice(invoice)
    invoice.buyer_name = buyer_name if buyer_name.present?
    invoice.buyer_ntn = buyer_ntn if buyer_ntn.present?
    invoice.buyer_province = buyer_province if buyer_province.present?
    invoice.buyer_address = buyer_address if buyer_address.present?
    invoice.buyer_registration_type = buyer_registration_type if buyer_registration_type.present?
    invoice.buyer_company_id = buyer_company_id if buyer_company_id.present?

    Array(items_data).each do |item_attrs|
      next if item_attrs.blank?

      invoice.items.build(item_attrs.stringify_keys.slice(
        'hs_code', 'description', 'quantity', 'uom', 'unit_price',
        'tax_rate', 'sale_type', 'sro_schedule_no'
      ))
    end
  end

  def self.capture_from_invoice(invoice, name:)
    create!(
      user: invoice.user,
      name: name,
      buyer_name: invoice.buyer_name,
      buyer_ntn: invoice.buyer_ntn,
      buyer_province: invoice.buyer_province,
      buyer_address: invoice.buyer_address,
      buyer_registration_type: invoice.buyer_registration_type,
      buyer_company_id: invoice.buyer_company_id,
      items_data: invoice.items.map do |item|
        {
          hs_code: item.hs_code,
          description: item.description,
          quantity: item.quantity,
          uom: item.uom,
          unit_price: item.unit_price,
          tax_rate: item.tax_rate,
          sale_type: item.sale_type,
          sro_schedule_no: item.sro_schedule_no
        }
      end
    )
  end
end
