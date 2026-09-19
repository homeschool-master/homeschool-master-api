# frozen_string_literal: true

module Api
  module V1
    # Scores only. Which students have an assignment is set through the
    # assignment's student_ids, so there is one way to do each thing rather
    # than two paths that can disagree.
    class AssignmentGradesController < BaseController
      before_action :set_assignment
      before_action :set_grade, only: :update

      # GET /api/v1/assignments/:assignment_id/grades
      def index
        render_success(@assignment.assignment_grades.map { |grade| AssignmentGradeSerializer.render(grade) })
      end

      # PATCH /api/v1/assignments/:assignment_id/grades/:id
      # points_earned null clears the score and puts the assignment back to
      # unmarked, which takes it out of the average again.
      def update
        if @grade.update(grade_params)
          render_success(AssignmentGradeSerializer.render(@grade))
        else
          render_validation_errors(@grade)
        end
      end

      private

      def set_assignment
        @assignment = current_teacher.assignments.find_by(id: params[:assignment_id])
        render_not_found('Assignment') if @assignment.nil?
      end

      def set_grade
        @grade = @assignment.assignment_grades.find_by(id: params[:id])
        render_not_found('Grade') if @grade.nil?
      end

      def grade_params
        params.permit(:points_earned, :notes)
      end
    end
  end
end
