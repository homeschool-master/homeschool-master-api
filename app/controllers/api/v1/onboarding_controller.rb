# frozen_string_literal: true

module Api
  module V1
    class OnboardingController < BaseController
      # PATCH /api/v1/onboarding
      def update
        if current_teacher.update(onboarding_completed: true)
          render_success(teacher_response(current_teacher))
        else
          render_validation_errors(current_teacher)
        end
      end
    end
  end
end
