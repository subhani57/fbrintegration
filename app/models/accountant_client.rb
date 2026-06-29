# frozen_string_literal: true

class AccountantClient < ApplicationRecord
  belongs_to :accountant, class_name: 'User'
  belongs_to :client, class_name: 'User'

  validate :accountant_must_be_accountant_role
  validate :client_must_be_taxpayer

  private

  def accountant_must_be_accountant_role
    return if accountant&.role == 'accountant'

    errors.add(:accountant, 'must have accountant role')
  end

  def client_must_be_taxpayer
    return if client&.taxpayer?

    errors.add(:client, 'must be a taxpayer account')
  end
end
