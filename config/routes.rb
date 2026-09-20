# frozen_string_literal: true

Rails.application.routes.draw do
  draw(:auth)

  namespace :api do
    namespace :v1 do
      patch 'profile', to: 'profile#update'
      patch 'profile/preferences', to: 'preferences#update'
      patch 'notifications', to: 'notifications#update'
      patch 'onboarding', to: 'onboarding#update'

      resources :subjects, :tasks, :calendar_events,
                only: %i[index show create update destroy]

      resources :students, only: %i[index show create update destroy] do
        get 'progress', to: 'progress#show'
      end

      resources :assignment_types, only: %i[index create update destroy]

      resources :assignments, only: %i[index show create update destroy] do
        resources :grades, only: %i[index update], controller: 'assignment_grades'
      end
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end
