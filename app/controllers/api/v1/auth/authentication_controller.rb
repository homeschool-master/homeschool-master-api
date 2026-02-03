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
            access_token = JwtService.encode({ teacher_id: teacher.id })

            jwt_token = JwtService.encode_refresh_token(teacher.id)
            decoded = JwtService.decode(jwt_token)
            refresh_token = teacher.refresh_tokens.create!(
              token: jwt_token,
              jti: decoded[:jti],
              expires_at: Time.at(decoded[:exp])
            )

            render json: { access_token:, refresh_token: jwt_token }, status: :ok
          else
            render json: { error: 'unauthorized' }, status: :unauthorized
          end
        end

        private

        def placeholder_method_to_shorten_login_method
        end
      end
    end
  end
end
