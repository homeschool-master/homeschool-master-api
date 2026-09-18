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
        task = current_teacher.tasks.build(task_params)

        if task.save
          render_created(TaskSerializer.render(task))
        else
          render_validation_errors(task)
        end
      end

      # PATCH /api/v1/tasks/:id
      # Ticking and unticking are both plain updates: completed is a writer on
      # the model that sets or clears the timestamp, so a checkbox needs one
      # endpoint rather than a complete and an uncomplete.
      def update
        if @task.update(task_params)
          render_success(TaskSerializer.render(@task))
        else
          render_validation_errors(@task)
        end
      end

      # DELETE /api/v1/tasks/:id
      # A hard delete, unlike students and subjects. Nothing references a task,
      # and a to-do a teacher deleted is meant to be gone rather than hidden.
      def destroy
        @task.destroy
        render_no_content
      end

      private

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
        params.permit(:title, :description, :due_date, :completed)
      end
    end
  end
end
