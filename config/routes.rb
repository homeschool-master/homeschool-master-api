# frozen_string_literal: true

Rails.application.routes.draw do
  draw(:auth)
  draw(:documents)

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

      # issue freezes a card, refresh pulls an unissued version's figures back
      # up to date, and versions lists every version of one card.
      resources :report_cards, only: %i[index show create update destroy] do
        post :issue, :refresh, on: :member
        get :versions, on: :member
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
