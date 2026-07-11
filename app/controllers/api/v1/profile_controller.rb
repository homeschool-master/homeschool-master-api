# frozen_string_literal: true

module Api
  module V1
    class ProfileController < BaseController
      # PATCH /api/v1/profile
      def update
        unless current_teacher.authenticate(params[:current_password])
          return render_unauthorized('Current password is incorrect')
        end

        current_teacher.assign_attributes(profile_params)

        if current_teacher.save
          render_success(teacher_response(current_teacher))
        else
          render_validation_errors(current_teacher)
        end
      end

      private

      def profile_params
        params.permit(:first_name, :middle_name, :last_name)
      end
    end
  end
end
