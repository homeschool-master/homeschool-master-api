# frozen_string_literal: true

module Api
  module V1
    # The weighted roll up for one student over one period, grouped by subject.
    class ProgressController < BaseController
      # GET /api/v1/students/:student_id/progress?from=&to=
      def show
        student = current_teacher.students.find_by(id: params[:student_id])
        return render_not_found('Student') if student.nil?

        range = parsed_range
        return if performed?

        render_success(ProgressReport.call(student: student, from: range.first, to: range.last))
      end

      private

      # Both ends are required: a roll up with no period is not a report card,
      # and silently defaulting to all time would quietly answer a different
      # question from the one asked.
      def parsed_range
        from = parse_date(params[:from], 'from')
        return if performed?

        to = parse_date(params[:to], 'to')
        return if performed?
        return render_invalid('to', 'must be on or after from') if to < from

        [from, to]
      end

      def parse_date(value, field)
        return render_invalid(field, 'is required') if value.blank?

        Date.parse(value.to_s)
      rescue Date::Error
        render_invalid(field, 'must be a valid date')
      end

      def render_invalid(field, message)
        render_error('Validation failed', code: 'VALIDATION_ERROR',
                                          status: :unprocessable_entity, details: { field => [message] })
        nil
      end
    end
  end
end
