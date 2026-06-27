# frozen_string_literal: true

class InvoiceTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer_portal!
  before_action :ensure_taxpayer!
  before_action :set_template, only: [:destroy]

  def index
    @templates = current_user.invoice_templates.ordered
  end

  def destroy
    @template.destroy
    redirect_to invoice_templates_path, notice: 'Template deleted.'
  end

  private

  def set_template
    @template = current_user.invoice_templates.find(params[:id])
  end
end
