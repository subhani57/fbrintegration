# frozen_string_literal: true

class PendingApprovalController < ApplicationController
  skip_before_action :ensure_approved_user!, only: [:show]
  skip_before_action :ensure_approved_user!

  def show
    redirect_to root_path if current_user.approved? || current_user.admin?
  end
end
