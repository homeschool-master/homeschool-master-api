# frozen_string_literal: true

# Drawn from config/routes.rb. The authentication surface is a third of the
# route table and changes on its own schedule, so it lives in its own file
# rather than pushing the application routes down the page.
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
  end
end
