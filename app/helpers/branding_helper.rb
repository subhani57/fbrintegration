# frozen_string_literal: true

module BrandingHelper
  def brand_nav_label(admin: false)
    admin ? "#{Branding::APP_SHORT_NAME} Admin" : Branding::APP_SHORT_NAME
  end

  def brand_company_name
    Branding::COMPANY_NAME
  end

  def brand_product_name
    Branding::PRODUCT_NAME
  end

  def brand_app_name
    Branding::APP_NAME
  end

  def brand_admin_app_name
    Branding::ADMIN_APP_NAME
  end

  def brand_tagline
    Branding::TAGLINE
  end

  def brand_support_email
    Branding::SUPPORT_EMAIL
  end

  def brand_page_title(page_title = nil)
    page_title.present? ? "#{page_title} — #{Branding::APP_NAME}" : Branding::APP_NAME
  end

  def brand_admin_page_title(page_title = nil)
    base = Branding::ADMIN_APP_NAME
    page_title.present? ? "#{page_title} — #{base}" : base
  end

  def brand_logo_image(css_class: 'brand-logo', **options)
    image_tag('logo.png', { alt: Branding::COMPANY_NAME, class: css_class }.merge(options))
  end

  def brand_banner_image(css_class: 'brand-banner', **options)
    image_tag('banner.png', { alt: '', class: css_class, role: 'presentation' }.merge(options))
  end
end
