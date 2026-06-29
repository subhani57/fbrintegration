# frozen_string_literal: true

class SupportTicketReply < ApplicationRecord
  belongs_to :support_ticket
  belongs_to :user

  validates :body, presence: true
end
