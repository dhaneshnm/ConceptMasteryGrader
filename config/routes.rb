Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Root route
  root "course_materials#index"
  
  # Course materials with nested resources
  resources :course_materials do
    resources :summaries, only: [:index, :create, :show, :destroy]
    resources :rubrics, only: [:index, :create, :show, :edit, :update, :destroy] 
    resources :conversations do
      resources :messages, only: [:create, :destroy]
      resources :grade_reports, only: [:index, :show, :create, :destroy] do
        collection do
          get :latest
          post :batch_evaluate
        end
      end
    end
  end
  
  # Instructor interface
  namespace :instructor do
    resources :dashboard, only: [:index] do
      collection do
        get :conversations
        get :analytics
        get :misconceptions
        post :batch_evaluate
      end
    end
    
    resources :course_materials, only: [] do
      resources :misconception_patterns do
        collection do
          post :detect_from_conversations
        end
      end
    end
  end
  
  # Sidekiq web UI for job monitoring (in development)
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
