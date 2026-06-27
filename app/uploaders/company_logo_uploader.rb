class CompanyLogoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_allowlist
    %w[jpg jpeg png gif webp]
  end

  def content_type_allowlist
    /image\//
  end

  version :thumb do
    process resize_to_limit: [200, 200]
  end
end
