# frozen_string_literal: true

class RecurringInvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_taxpayer!
  before_action :set_recurring, only: [:edit, :update, :destroy, :run]

  def index
    @recurring_invoices = portal_user.recurring_invoices.order(:next_run_on)
  end

  def new
    @recurring = portal_user.recurring_invoices.new(next_run_on: Date.current + 1.month, frequency: 'monthly')
  end

  def create
    @recurring = portal_user.recurring_invoices.new(recurring_params)
    if @recurring.save
      redirect_to recurring_invoices_path, notice: 'Recurring invoice schedule created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recurring.update(recurring_params)
      redirect_to recurring_invoices_path, notice: 'Schedule updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring.destroy
    redirect_to recurring_invoices_path, notice: 'Schedule removed.'
  end

  def run
    invoice = @recurring.run!
    redirect_to invoice_path(invoice), notice: 'Invoice generated from schedule.'
  end

  private

  def set_recurring
    @recurring = portal_user.recurring_invoices.find(params[:id])
  end

  def recurring_params
    params.require(:recurring_invoice).permit(:name, :frequency, :next_run_on, :active, :invoice_template_id, :buyer_company_id, template_data: {})
  end
end
