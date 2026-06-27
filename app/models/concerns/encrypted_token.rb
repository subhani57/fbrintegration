# frozen_string_literal: true

module EncryptedToken
  extend ActiveSupport::Concern

  ENCRYPTED_PREFIX = 'enc:v1:'

  included do
    attr_accessor :token_input
  end

  def token
    raw = read_attribute(:token)
    ciphertext = read_attribute(:token_ciphertext)
    decrypt_value(ciphertext.presence || raw)
  end

  def token=(value)
    plain = value.to_s.strip
    if plain.blank?
      write_attribute(:token, nil)
      write_attribute(:token_ciphertext, nil)
      return
    end

    write_attribute(:token, nil)
    write_attribute(:token_ciphertext, encrypt_value(plain))
  end

  def token_configured?
    token.present?
  end

  private

  def encryptor
    key = Rails.application.key_generator.generate_key('fbr_token_encryption', 32)
    ActiveSupport::MessageEncryptor.new(key)
  end

  def encrypt_value(plain)
    return plain if plain.start_with?(ENCRYPTED_PREFIX)

    "#{ENCRYPTED_PREFIX}#{encryptor.encrypt_and_sign(plain)}"
  end

  def decrypt_value(stored)
    return nil if stored.blank?
    return stored unless stored.start_with?(ENCRYPTED_PREFIX)

    encryptor.decrypt_and_verify(stored.delete_prefix(ENCRYPTED_PREFIX))
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    stored
  end
end
