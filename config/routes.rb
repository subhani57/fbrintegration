# config/routes.rb
Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    passwords: 'users/passwords'
  }
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Dashboard (taxpayers)
  root 'root#index'
  get 'dashboard', to: 'dashboard#index'
  get 'reports', to: 'dashboard#reports'

  get 'pending_approval', to: 'pending_approval#show'
  resource :onboarding, only: [:show, :update], controller: 'onboarding'
  post 'onboarding/skip', to: 'onboarding#skip', as: :skip_onboarding

  resources :notifications, only: [:index] do
    collection { patch :mark_all_read }
  end

  resources :webhooks, except: [:show]
  resources :invoice_templates, only: [:index, :destroy]
  
  resources :invoices do
    member do
      post :submit
      post :validate
      post :cancel
      post :save_template
      post :sync_from_iris
      post :mark_cancelled_on_iris
      get :status
      get :download_pdf
    end
    collection do
      post :bulk_submit
    end
  end

  resources :companies

  # FBR / IRIS registered invoices (download & lookup)
  resources :fbr_invoices, only: [:index, :show] do
    member do
      get :download_pdf
      post :sync_from_fbr
    end
    collection do
      post :lookup
    end
  end

  # Business profile + FBR settings (combined)
  resource :profile, only: [:show, :edit, :update] do
    patch :preferred_environment, on: :collection
  end

  # Legacy FBR URLs → profile
  get 'fbr_configurations', to: redirect('/profile')
  get 'fbr_configurations/new', to: redirect('/profile/edit')
  get 'fbr_configurations/:id/edit', to: redirect('/profile/edit')

  # Admin portal
  namespace :admin do
    get 'dashboard', to: 'dashboard#index'
    resources :users do
      member do
        post :send_test_fbr_invoices
        patch :preferred_fbr_environment
        patch :approve
      end
    end
    resources :invoices, only: [:index, :show] do
      member do
        get :download_pdf
      end
    end
    resources :reports, only: [:index]
    resources :fbr_configurations, only: [:index, :edit, :update]
    resources :fbr_logs, only: [:index]
  end

  # API (reference data — authenticated)
  namespace :api do
    namespace :v1 do
      resources :reference_data, only: [:index] do
        collection do
          get :provinces
          get :hs_codes
          get :search_hs_codes, path: "hs_codes/search"
          get :uom
          get :rates
          get :sro_schedule
          get :sro_item
          get :hs_uom
        end
      end
      resources :invoices, only: [:index, :show, :create] do
        member do
          post :submit
          post :validate
        end
      end
      resources :buyer_validations, only: [:create]
    end
  end
  
  # Sidekiq Web UI
  require 'sidekiq/web'
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end
end
