# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      include SeriesEditing
      include TaskListing
      include SubmittedStudents
      include TaskSeries

      before_action :set_task, only: %i[show update destroy]

      # GET /api/v1/tasks?completed=&due_by=&from=&to=
      #
      # Ordinary tasks and the occurrences of repeating ones, in one list.
      # The filters apply to occurrences rather than rows, so completed=false
      # on a weekly task means the weeks still to do rather than the whole
      # series disappearing the moment one week is ticked.
      def index
        window = parsed_window
        return if performed?

        entries = filtered_entries(TaskFeed.call(teacher: current_teacher, from: window.first,
                                                 to: window.last))
        return if performed?

        render_success(entries.map { |entry| render_entry(entry) })
      end

      # GET /api/v1/tasks/:id
      #
      # A bare uuid for an ordinary task, or "<uuid>:<date>" for one occurrence
      # of a series: an occurrence has no row of its own, so it is named by its
      # series and the date it falls on.
      def show
        render_success(TaskSerializer.render(@task, occurrence: shown_occurrence))
      end

      # POST /api/v1/tasks
      def create
        student_ids = submitted_student_ids
        return render_unowned_students if student_ids && !students_owned?(student_ids)

        task = build_task_with_rule(student_ids)
        return if performed?

        task.save!
        render_created(TaskSerializer.render(task))
      end

      # PATCH /api/v1/tasks/:id
      #
      # Ticking an occurrence is not an edit of the series. It writes one row
      # naming that date, so this week's tick leaves next week alone, and
      # unticking deletes that row again. A tick that arrives with nothing else
      # is answered there and then; one that arrives alongside real edits falls
      # through to the scope machinery, which carries it onto the detached
      # occurrence.
      def update
        student_ids = submitted_student_ids
        return render_unowned_students if student_ids && !students_owned?(student_ids)
        return render_invalid_scope unless valid_scope?

        apply_occurrence_completion if occurrence_completion?
        return render_success(TaskSerializer.render(@task, occurrence: shown_occurrence)) if tick_only?

        update_series_or_record(student_ids)
      end

      # DELETE /api/v1/tasks/:id
      # A hard delete, unlike students and subjects. scope reaches as far on a
      # series as it does on update.
      def destroy
        return render_invalid_scope unless valid_scope?

        destroy_series_or_record
        render_no_content
      end

      private

      def set_task
        id, @occurrence_date = TaskSerializer.parse_id(params[:id])
        @task = current_teacher.tasks.find_by(id: id)
        render_not_found('Task') if @task.nil?
      end

      # Top-level params, the same as students, subjects and calendar events.
      # completed is not a column: it is the model writer that sets or clears
      # completed_at, which is why completed_at itself is not accepted here.
      def task_params
        params.permit(:title, :description, :due_date, :completed, :owned_by)
      end
    end
  end
end
