# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user

  validates :title, presence: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_read!
    update!(read: true)
  end

  def self.notify!(user, title:, body: nil, notification_type: 'info', link_path: nil)
    create!(
      user: user,
      title: title,
      body: body,
      notification_type: notification_type,
      link_path: link_path
    )
  end
end
