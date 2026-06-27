# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    user&.can_access_taxpayer_portal?
  end

  def show?
    owner_or_viewer?
  end

  def status?
    show?
  end

  def create?
    user&.can_manage_invoices?
  end

  def update?
    user&.can_manage_invoices? && record.user_id == user.id && !record.fbr_locked?
  end

  def destroy?
    update? && record.draft?
  end

  def submit?
    user&.can_manage_invoices? && record.user_id == user.id
  end

  def validate?
    submit?
  end

  def cancel?
    user&.can_manage_invoices? && record.user_id == user.id && record.may_cancel?
  end

  def edit?
    update?
  end

  def save_template?
    user&.can_manage_invoices? && record.user_id == user.id
  end

  def sync_from_iris?
    user&.can_manage_invoices? && record.user_id == user.id && record.fbr_invoice_id.present?
  end

  def mark_cancelled_on_iris?
    sync_from_iris? && !record.iris_cancelled? &&
      (record.fbr_status == 'submitted' || %w[submitted approved].include?(record.status))
  end

  def download_pdf?
    owner_or_viewer?
  end

  def download_xml?
    owner_or_viewer?
  end

  def bulk_submit?
    user&.can_manage_invoices?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.admin?
        scope.all
      elsif user.can_access_taxpayer_portal?
        scope.where(user_id: user.id)
      else
        scope.none
      end
    end
  end

  private

  def owner_or_viewer?
    return false unless user

    user.admin? || (user.can_access_taxpayer_portal? && record.user_id == user.id)
  end
end
