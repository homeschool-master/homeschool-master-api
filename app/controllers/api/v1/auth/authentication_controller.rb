# frozen_string_literal: true

module Api
  module V1
    module Auth
      class AuthenticationController < BaseController
        skip_before_action :authenticate_request

        def login
          teacher = Teacher.find_by(email: params[:email])
          authenticated_teacher = teacher&.authenticate(params[:password])

          if authenticated_teacher
            tokens = generate_tokens(teacher)
            render json: tokens, status: :ok
          else
            render json: { error: 'unauthorized' }, status: :unauthorized
          end
        end

        private

        def generate_tokens(teacher)
          access_token = JwtService.encode({ teacher_id: teacher.id })

          jwt_token = JwtService.encode_refresh_token(teacher.id)
          decoded = JwtService.decode(jwt_token)
          teacher.refresh_tokens.create!(
            token: jwt_token,
            jti: decoded[:jti],
            expires_at: Time.at(decoded[:exp])
          )

          { access_token:, refresh_token: jwt_token }
        end
      end
    end
  end
end
