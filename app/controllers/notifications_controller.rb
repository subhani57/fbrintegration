# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.recent.page(params[:page]).per(20)
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read: true)
    redirect_to notifications_path, notice: 'All notifications marked as read.'
  end
end
