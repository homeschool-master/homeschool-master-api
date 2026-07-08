# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post 'register', to: 'authentication#register'
        post 'login', to: 'authentication#login'
        post 'refresh', to: 'authentication#refresh'
        post 'logout', to: 'authentication#logout'
        get 'me', to: 'authentication#me'
        post 'password/reset-request', to: 'passwords#reset_request'
        post 'password/reset', to: 'passwords#reset'
        post 'password/change', to: 'passwords#change'
        post 'email/verify', to: 'email_verification#verify'
        post 'email/resend-verification', to: 'email_verification#resend'
        post 'email/change', to: 'email_change#request_change'
        post 'email/change/confirm', to: 'email_change#confirm'
      end

      # Application routes (authenticated)
      patch 'profile', to: 'profile#update'
      patch 'notifications', to: 'notifications#update'
      patch 'onboarding', to: 'onboarding#update'
      resources :students, only: %i[index show create update destroy]
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end
