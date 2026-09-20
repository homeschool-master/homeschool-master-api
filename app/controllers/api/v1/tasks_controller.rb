# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      before_action :set_task, only: %i[show update destroy]

      # GET /api/v1/tasks?completed=&due_by=
      #
      # One collection serving two readers. The full list sends no filters and
      # gets everything. The dashboard panel sends completed=false, and adds
      # due_by when it wants a window: completed=false with due_by set to today
      # is the overdue query, so nothing needs a separate endpoint for it.
      #
      # Order is the same either way: soonest due first, undated last.
      def index
        tasks = filtered_tasks
        return if performed?

        render_success(tasks.map { |task| TaskSerializer.render(task) })
      end

      # GET /api/v1/tasks/:id
      def show
        render_success(TaskSerializer.render(@task))
      end

      # POST /api/v1/tasks
      def create
        student_ids = submitted_student_ids
        return render_unowned_students if student_ids && !students_owned?(student_ids)

        task = current_teacher.tasks.build(task_params)
        task.students = students_for(student_ids) unless student_ids.nil?
        return render_validation_errors(task) unless task.valid?

        task.save!
        render_created(TaskSerializer.render(task))
      end

      # PATCH /api/v1/tasks/:id
      # Ticking and unticking are both plain updates: completed is a writer on
      # the model that sets or clears the timestamp, so a checkbox needs one
      # endpoint rather than a complete and an uncomplete.
      #
      # A submitted student array replaces the existing set outright, the same
      # as event attendees. Taking the last student off a task that is a
      # student's is refused by the model rather than quietly making it the
      # teacher's, so the assignment happens before validity is checked.
      def update
        student_ids = submitted_student_ids
        return render_unowned_students if student_ids && !students_owned?(student_ids)

        return render_validation_errors(@task) unless apply_update(student_ids)

        render_success(TaskSerializer.render(@task))
      end

      # DELETE /api/v1/tasks/:id
      # A hard delete, unlike students and subjects. Nothing references a task,
      # and a to-do a teacher deleted is meant to be gone rather than hidden.
      def destroy
        @task.destroy
        render_no_content
      end

      private

      # Assigning a collection on a record that already exists writes the join
      # rows there and then, before anything has been validated. Without the
      # transaction, refusing to take the last student off a task that is a
      # student's would return the refusal having already deleted the row it
      # was refusing to delete.
      def apply_update(student_ids)
        @task.transaction do
          @task.assign_attributes(task_params)
          @task.students = students_for(student_ids) unless student_ids.nil?
          raise ActiveRecord::Rollback unless @task.valid?

          @task.save!
          true
        end
      end

      def filtered_tasks
        tasks = current_teacher.tasks.by_due_date
        tasks = apply_completed_filter(tasks)
        return tasks if performed?

        apply_due_by_filter(tasks)
      end

      def apply_completed_filter(tasks)
        return tasks if params[:completed].blank?

        case params[:completed]
        when 'true' then tasks.completed
        when 'false' then tasks.open
        else render_invalid_filter('completed', 'must be true or false')
        end
      end

      def apply_due_by_filter(tasks)
        return tasks if params[:due_by].blank?

        date = begin
          Date.parse(params[:due_by].to_s)
        rescue Date::Error
          nil
        end
        return render_invalid_filter('due_by', 'must be a valid date') if date.nil?

        tasks.due_by(date)
      end

      # A filter that cannot be honored is an error rather than something to
      # drop quietly: a dashboard silently showing every task would look like
      # it was working.
      def render_invalid_filter(field, message)
        render_error(
          'Validation failed',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity,
          details: { field => [message] }
        )
      end

      def set_task
        @task = current_teacher.tasks.find_by(id: params[:id])
        render_not_found('Task') if @task.nil?
      end

      # Top-level params, the same as students, subjects and calendar events.
      # completed is not a column: it is the model writer that sets or clears
      # completed_at, which is why completed_at itself is not accepted here.
      def task_params
        params.permit(:title, :description, :due_date, :completed, :owned_by)
      end

      # nil means the client did not submit students at all, so the existing
      # set is left alone. An empty array clears it, which the model then
      # refuses on a task that is a student's.
      def submitted_student_ids
        return nil unless params.key?(:student_ids)

        Array(params.permit(student_ids: [])[:student_ids]).uniq
      end

      # Loaded through the teacher, so an id belonging to someone else cannot
      # arrive here even if the check above were ever bypassed.
      def students_for(student_ids)
        return [] if student_ids.empty?

        current_teacher.students.where(id: student_ids).to_a
      end

      # The same rule event attendees have: one id belonging to another teacher
      # rejects the whole request rather than being dropped from it, because a
      # task quietly saved without the student it named is worse than one that
      # was refused.
      def students_owned?(student_ids)
        return true if student_ids.empty?

        current_teacher.students.where(id: student_ids).count == student_ids.size
      end

      def render_unowned_students
        render_error(
          'Validation failed',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity,
          details: { student_ids: ['must all belong to the current teacher'] }
        )
      end
    end
  end
end
