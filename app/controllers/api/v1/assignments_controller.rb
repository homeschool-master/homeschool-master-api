# frozen_string_literal: true

module Api
  module V1
    class AssignmentsController < BaseController
      before_action :set_assignment, only: %i[show update destroy]

      # GET /api/v1/assignments?subject_id=&due_from=&due_to=
      def index
        assignments = filtered_assignments
        return if performed?

        render_success(assignments.map { |assignment| AssignmentSerializer.render(assignment) })
      end

      # GET /api/v1/assignments/:id
      def show
        render_success(AssignmentSerializer.render(@assignment))
      end

      # POST /api/v1/assignments
      # student_ids assigns the work: each id becomes an unmarked grade row.
      def create
        student_ids = submitted_student_ids
        return render_unowned_students if student_ids && !students_owned?(student_ids)

        assignment = current_teacher.assignments.build(with_default_type(assignment_params))
        return render_validation_errors(assignment) unless assignment.valid?

        save_with_students(assignment, student_ids)
        render_created(AssignmentSerializer.render(assignment))
      end

      # PATCH /api/v1/assignments/:id
      #
      # A submitted student_ids array replaces the assigned set outright, the
      # same as calendar event attendees. Note that removing a student here
      # deletes their grade row, score and all: unassigning is destructive by
      # design, because the alternative is orphan scores for work the student
      # is no longer doing.
      def update
        student_ids = submitted_student_ids
        return render_unowned_students if student_ids && !students_owned?(student_ids)

        @assignment.assign_attributes(assignment_params)
        return render_validation_errors(@assignment) unless @assignment.valid?

        save_with_students(@assignment, student_ids)
        render_success(AssignmentSerializer.render(@assignment))
      end

      # DELETE /api/v1/assignments/:id
      # Hard delete, taking its grades with it: an assignment the teacher
      # removed is work that was never set, not work to keep a record of.
      def destroy
        @assignment.destroy
        render_no_content
      end

      private

      def filtered_assignments
        all = current_teacher.assignments.includes(:assignment_grades, :assignment_type).chronological
        apply_due_range(narrowed(all))
      end

      def narrowed(assignments)
        assignments = assignments.for_subject(params[:subject_id]) if params[:subject_id].present?
        assignments = assignments.for_type(params[:assignment_type_id]) if params[:assignment_type_id].present?
        assignments
      end

      def apply_due_range(assignments)
        from = parse_date(params[:due_from], 'due_from')
        return assignments if performed?

        to = parse_date(params[:due_to], 'due_to')
        return assignments if performed?
        return assignments if from.nil? && to.nil?

        assignments.due_between(from || Date.new(1, 1, 1), to || Date.new(9999, 12, 31))
      end

      def parse_date(value, field)
        return nil if value.blank?

        Date.parse(value.to_s)
      rescue Date::Error
        render_invalid_filter(field, 'must be a valid date')
        nil
      end

      def render_invalid_filter(field, message)
        render_error('Validation failed', code: 'VALIDATION_ERROR',
                                          status: :unprocessable_entity, details: { field => [message] })
      end

      def set_assignment
        @assignment = current_teacher.assignments.find_by(id: params[:id])
        render_not_found('Assignment') if @assignment.nil?
      end

      # A request that names no type gets the ordinary one. Types arrived after
      # this endpoint did, and work set without saying what kind it is has
      # always been an assignment.
      def with_default_type(attributes)
        return attributes if attributes[:assignment_type_id].present?

        attributes.merge(assignment_type_id: default_type_id)
      end

      def default_type_id
        current_teacher.assignment_types.active.built_in
                       .find_by(name: 'Assignment')&.id
      end

      def assignment_params
        params.permit(:subject_id, :assignment_type_id, :title, :description, :due_date, :points_possible, :weight)
      end

      # nil means the client did not submit the set at all, so it is left alone.
      # An empty array unassigns everyone.
      def submitted_student_ids
        return nil unless params.key?(:student_ids)

        Array(params.permit(student_ids: [])[:student_ids]).uniq
      end

      def students_owned?(student_ids)
        return true if student_ids.empty?

        current_teacher.students.where(id: student_ids).count == student_ids.size
      end

      def render_unowned_students
        render_error('Validation failed', code: 'VALIDATION_ERROR', status: :unprocessable_entity,
                                          details: { student_ids: ['must all belong to the current teacher'] })
      end

      # Adds and removes rather than rebuilding, so a student who stays on the
      # assignment keeps the score already recorded against them.
      def save_with_students(assignment, student_ids)
        assignment.transaction do
          assignment.save!
          next if student_ids.nil?

          assignment.assignment_grades.where.not(student_id: student_ids).destroy_all
          existing = assignment.assignment_grades.pluck(:student_id)
          (student_ids - existing).each { |id| assignment.assignment_grades.create!(student_id: id) }
        end
        assignment.assignment_grades.reload
      end
    end
  end
end
