# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record!(user:, action:, auditable: nil, metadata: {}, request: nil)
    create!(
      user: user,
      action: action,
      auditable_type: auditable&.class&.name,
      auditable_id: auditable&.id,
      metadata: metadata,
      ip_address: request&.remote_ip
    )
  end
end
