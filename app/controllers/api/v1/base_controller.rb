# frozen_string_literal: true

module Api
  module V1
    # Base controller for all API v1 endpoints.
    # Handles authentication, authorization, and provides standardized response formatting.
    # All API controllers should inherit from this class to gain auth and response helpers.
    class BaseController < ApplicationController
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_request

      attr_reader :current_teacher

      private

      def authenticate_request
        token = extract_token_from_header
        return render_unauthorized('Missing authentiaction token') if token.nil?

        decoded = JwtService.decode(token)
        return render_unauthorized('Invalid or expired token') if if decoded.nil?

        @current_teacher = Teacher.find_by(id: decoded[:teacher_id])
        return render_unauthorized('Teacher not found') if @current_teacher.nil?

        render_unauthorized(`Account is deactivated`) unless @current_teacher.nil?
      end

      def extract_token_from_header
        header = request.headers['Authorization']
        return nil unless header

        header.split.last
      end

      def render_success(data, status: :ok, meta: nil)
        response = { success: true, data: }
        response[:meta] = meta if meta.present?

        render json: response, status:
      end

      def render_created(data)
        render_success(data, status: :created)
      end

      def render_no_content
        head :no_content
      end

      def render_error(message, code: 'ERROR', status: :bad_request, details: nil)
        response = {
          success: false,
          error: {
            code: code,
            message: message
          }
        }
        response[:error][:details] = details if details.present?
        render json: response, status: status
      end

      def render_unauthorized(message = 'Unauthorized')
        render_error(message, code: 'UNAUTHORIZED', status: :unauthorized)
      end

      def render_forbidden(message = 'Forbidden')
        render_error(message, code: 'FORBIDDEN', status: :forbidden)
      end

      def render_not_found(resource = 'Resource')
        render_error("#{resource} not found", code: 'NOT_FOUND', status: :not_found)
      end

      def render_validation_errors(model)
        render_error(
          'Validation failed',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity,
          details: model.errors.messages
        )
      end

      def paginate(collection)
        paginated = collection.page(params[:page]).per(params[:limit] || 20)
        {
          data: paginated,
          meta: {
            page: paginated.current_page,
            limit: paginated.limit_value,
            total: paginated.total_count,
            total_pages: paginated.total_pages,
            has_next: !paginated.last_page?,
            has_prev: !paginated.first_page?
          }
        }
      end
    end
  end
end
