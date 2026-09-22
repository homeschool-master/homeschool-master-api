# frozen_string_literal: true

# Drawn from config/routes.rb, the way the auth routes are.
#
# download is the only way to the bytes: there is no public link and no rails
# blob path handed out, so every read goes through an action that checks the
# owner first. attachments file one document against an assignment, a task or
# a calendar event, and are nested because a filing has no life of its own.
namespace :api do
  namespace :v1 do
    resources :documents, only: %i[index show create update destroy] do
      post :upload_url, on: :collection
      get :download, on: :member
      resources :attachments, only: %i[create destroy], controller: 'document_attachments'
    end
  end
end
