class CompaniesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_admin_from_taxpayer_portal!
  before_action :ensure_taxpayer!
  before_action :set_company, only: [:show, :edit, :update, :destroy]

  def index
    @companies = portal_user.companies.ordered
  end

  def show
    redirect_to edit_company_path(@company)
  end

  def new
    @company = portal_user.companies.build
  end

  def create
    @company = portal_user.companies.build(company_params)

    if @company.save
      redirect_to companies_path, notice: 'Buyer company saved.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @company.update(company_params)
      redirect_to companies_path, notice: 'Buyer company updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy
    redirect_to companies_path, notice: 'Buyer company removed.'
  end

  private

  def set_company
    @company = portal_user.companies.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:name, :ntn, :address, :phone, :email)
  end
end
