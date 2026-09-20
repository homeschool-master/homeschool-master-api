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
      #
      # Two ways to say the same thing. A percentage is typed as points_earned;
      # a letter is sent as entered_letter and becomes a score here, once, so
      # nothing downstream has to know which way it was entered. points_earned
      # null clears the score and puts the assignment back to unmarked, which
      # takes it out of the average again.
      def update
        return render_invalid_letter unless letter_valid?

        apply_letter if letter_given?
        @grade.assign_attributes(scored_params)

        if @grade.save
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
        params.permit(:points_earned, :notes, :entered_letter)
      end

      def letter_given?
        params[:entered_letter].present?
      end

      def letter_valid?
        !letter_given? || LetterScale.valid_letter?(params[:entered_letter])
      end

      def apply_letter
        @grade.apply_letter(params[:entered_letter])
      end

      # A letter already set the score, so a points_earned riding along in the
      # same request is ignored rather than fighting it. Typing a number is the
      # other way round: it clears the letter, because the mark is no longer
      # the one she picked.
      def scored_params
        attributes = grade_params.except(:entered_letter)
        return attributes.except(:points_earned) if letter_given?
        return attributes unless params.key?(:points_earned)

        attributes.merge(entered_letter: nil)
      end

      def render_invalid_letter
        message = "must be one of #{LetterScale.letters.join(', ')}"
        render_error('Validation failed', code: 'VALIDATION_ERROR', status: :unprocessable_entity,
                                          details: { entered_letter: [message] })
      end
    end
  end
end
