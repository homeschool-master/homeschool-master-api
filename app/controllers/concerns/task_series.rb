# frozen_string_literal: true

# How a task behaves as a series: the hooks SeriesEditing asks for, answered in
# the task's terms, and the one thing a task has that an event does not, which
# is a tick recorded against a single occurrence.
#
# Its own file because none of it is about handling a request. The controller
# says what a request is; this says what a repeating task is.
module TaskSeries
  extend ActiveSupport::Concern

  private

  # The hooks SeriesEditing asks for, answered in the task's terms.
  def series_record
    @task
  end

  def series_editor
    TaskSeriesEdit.new(@task, occurrence_date: @occurrence_date)
  end

  def series_params
    task_params
  end

  def render_series(record)
    TaskSerializer.render(record)
  end

  # Students are assigned before validity is checked, because a task that
  # is a student's is invalid without one, and inside a transaction because
  # assigning a collection on a saved row writes the join rows immediately:
  # refusing the change afterwards would already have made it.
  def apply_whole_update(student_ids)
    saved = false
    @task.transaction do
      @task.assign_attributes(task_params)
      @task.students = students_for(student_ids) unless student_ids.nil?
      rule = assign_rule(@task)
      saved = save_whole(rule)
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end

  def save_whole(rule)
    return render_validation_errors(@task) && false unless @task.valid?
    return render_validation_errors(rule) && false if rule&.invalid?

    @task.save!
    rule&.save!
    # A task that has stopped repeating has no occurrences left for its
    # ticks to belong to, so they go with the rule.
    @task.task_completions.destroy_all if @task.recurrence.nil?
    true
  end

  # The task and its rule are validated together, so a bad rule rejects the
  # whole request rather than leaving a task behind that does not repeat.
  def build_task_with_rule(student_ids)
    task = current_teacher.tasks.build(task_params)
    task.students = students_for(student_ids) unless student_ids.nil?
    rule = assign_rule(task)
    render_validation_errors(task) unless task.valid?
    render_validation_errors(rule) if !performed? && rule&.invalid?
    task
  end

  # True when this request names one occurrence of a real series and says
  # something about whether it is done.
  def occurrence_completion?
    @occurrence_date.present? && @task.recurring? && params.key?(:completed)
  end

  # A tick on its own, with no edit riding along with it.
  def tick_only?
    return false unless occurrence_completion?

    task_params.to_h.except('completed').empty? && !params.key?(:student_ids) &&
      !params.key?(:recurrence)
  end

  # The row existing is the tick, so unticking deletes it rather than
  # nulling a column. Re-ticking an occurrence already done keeps the
  # original time, the way the column does.
  def apply_occurrence_completion
    completion = @task.task_completions.find_or_initialize_by(occurrence_date: @occurrence_date)

    if ActiveModel::Type::Boolean.new.cast(params[:completed])
      completion.completed_at ||= Time.current
      completion.save!
    else
      completion.destroy
    end
    @task.task_completions.reload
  end

  # Showing one occurrence rebuilds just that one, so its date and its tick
  # are its own rather than the series anchor's.
  def shown_occurrence
    return nil if @occurrence_date.nil? || !@task.recurring?

    TaskOccurrences.call(@task, from: @occurrence_date, to: @occurrence_date).first
  end

  def render_entry(entry)
    TaskSerializer.render(entry.task, occurrence: entry.occurrence)
  end
end
