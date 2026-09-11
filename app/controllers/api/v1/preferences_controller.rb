# frozen_string_literal: true

module Api
  module V1
    # Non sensitive teacher settings. These are display preferences rather than
    # credentials, so unlike ProfileController this endpoint does not gate on
    # current_password: the client persists a detected timezone without being
    # able to prompt for one.
    class PreferencesController < BaseController
      # Attributes a teacher may change without re-entering their password.
      # Future display and notification settings belong here, not on the
      # password gated profile endpoint.
      PERMITTED_ATTRIBUTES = %i[time_zone].freeze

      # PATCH /api/v1/profile/preferences
      def update
        current_teacher.assign_attributes(preference_params)

        if current_teacher.save
          render_success(teacher_response(current_teacher))
        else
          render_validation_errors(current_teacher)
        end
      end

      private

      def preference_params
        params.permit(*PERMITTED_ATTRIBUTES)
      end
    end
  end
end
