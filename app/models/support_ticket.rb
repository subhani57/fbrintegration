# frozen_string_literal: true

class SupportTicket < ApplicationRecord
  STATUSES = %w[open in_progress resolved closed].freeze
  PRIORITIES = %w[low normal high].freeze

  belongs_to :user
  belongs_to :assigned_admin, class_name: 'User', optional: true
  has_many :replies, class_name: 'SupportTicketReply', dependent: :destroy

  validates :subject, :body, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }

  scope :open, -> { where(status: %w[open in_progress]) }
  scope :recent, -> { order(updated_at: :desc) }

  def open?
    status.in?(%w[open in_progress])
  end

  def reply!(author:, body:, staff: false)
    transaction do
      replies.create!(user: author, body: body, staff_reply: staff)
      update!(status: staff ? 'in_progress' : 'open') if open?
    end
  end
end
