# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < BaseController
      # PATCH /api/v1/notifications
      def update
        current_teacher.assign_attributes(notification_params)

        if current_teacher.save
          render_success(teacher_response(current_teacher))
        else
          render_validation_errors(current_teacher)
        end
      end

      private

      def notification_params
        params.permit(
          :notify_account_updates,
          :notify_product_updates,
          :notify_homeschool_resources
        )
      end
    end
  end
end
