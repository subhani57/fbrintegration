# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :user

  validates :name, :token_digest, :token_prefix, presence: true

  scope :active, -> { where(active: true) }

  before_validation :generate_credentials, on: :create

  attr_reader :plain_token

  def self.authenticate(token)
    return nil if token.blank?

    digest = Digest::SHA256.hexdigest(token)
    key = active.find_by(token_digest: digest)
    key&.touch_last_used!
    key
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def revoke!
    update!(active: false)
  end

  private

  def generate_credentials
    @plain_token = SecureRandom.hex(32)
    self.token_prefix = @plain_token.first(8)
    self.token_digest = Digest::SHA256.hexdigest(@plain_token)
  end
end
