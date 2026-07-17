# frozen_string_literal: true

module Api
  module V1
    module Auth
      class AuthenticationController < BaseController
        skip_before_action :authenticate_request, only: %i[login register refresh logout]

        def login
          result = AuthenticationService.call(params[:email], params[:password])
          result[:success] ? handle_successful_login(result[:teacher]) : render_unauthorized(result[:error])
        end

        def register
          teacher = Teacher.new(register_params)

          if teacher.save
            render_created(teacher_response(teacher))
          else
            render_validation_errors(teacher)
          end
        end

        def refresh
          refresh_token = cookies[:refresh_token]
          result = AuthenticationService.refresh(refresh_token)

          if result[:success]
            access_token = JwtService.encode({ teacher_id: result[:teacher_id] })
            set_cookie(:access_token, access_token)
            render json: { success: true }, status: :ok
          else
            render_unauthorized(result[:error])
          end
        end

        def logout
          refresh_token = cookies[:refresh_token]
          token_record = RefreshToken.find_by(token: refresh_token)
          token_record&.revoke!
          clear_auth_cookies
          head :no_content
        end

        def me
          render_success(teacher_response(current_teacher))
        end

        private

        def handle_successful_login(teacher)
          tokens = generate_tokens(teacher)
          set_auth_cookies(tokens[:access_token], tokens[:refresh_token])
          render_success(teacher_response(teacher))
        end

        def register_params
          params.permit(:first_name, :middle_name, :last_name, :email, :password)
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

          { access_token:, refresh_token: jwt_token, user: teacher_response(teacher) }
        end

        def set_auth_cookies(access_token, refresh_token)
          set_cookie(:access_token, access_token)
          set_cookie(:refresh_token, refresh_token)
        end

        def set_cookie(name, value)
          cookies[name] = {
            value: value,
            httponly: true,
            secure: Rails.env.production?,
            same_site: cookie_same_site,
            expires: 7.days.from_now
          }
        end

        def clear_auth_cookies
          cookies.delete(:access_token, same_site: cookie_same_site, secure: Rails.env.production?)
          cookies.delete(:refresh_token, same_site: cookie_same_site, secure: Rails.env.production?)
        end

        # Vercel and Heroku are separate registrable domains, so production API
        # calls are cross-site and Lax cookies would never attach. None requires
        # Secure, which holds since both hosts are HTTPS.
        def cookie_same_site
          Rails.env.production? ? :none : :lax
        end
      end
    end
  end
end
