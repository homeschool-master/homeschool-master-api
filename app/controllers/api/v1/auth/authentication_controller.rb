# frozen_string_literal: true

module Api
  module V1
    module Auth
      class AuthenticationController < BaseController
        skip_before_action :authenticate_request, only: %i[login register]

        def login
          result = AuthenticationService.call(params[:email], params[:password])

          if result[:success]
            tokens = generate_tokens(result[:teacher])
            render json: tokens, status: :ok
          else
            render_unauthorized(result[:error])
          end
        end

        def register
          teacher = Teacher.new(register_params)

          if teacher.save
            render_created(teacher_response(teacher))
          else
            render_validation_errors(teacher)
          end
        end

        private

        def register_params
          params.permit(:first_name, :last_name, :email, :password)
        end

        def teacher_response(teacher)
          {
            id: teacher.id,
            first_name: teacher.first_name,
            last_name: teacher.last_name,
            email: teacher.email,
            created_at: teacher.created_at
          }
        end

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
