# frozen_string_literal: true

# Editing and deleting one occurrence of a repeating task, in the same three
# ways the calendar offers: this occurrence, this and everything after it, or
# all of it.
#
# The shape is EventSeriesEdit's, because the choice is the same choice. What
# differs is only what an occurrence is made of: a task's is a due date, so
# there are no instants and no zone anywhere in here.
#
# All three modes are meaningful for a task. "This occurrence" is the one a
# repeating to-do needs most: this week's reimbursement was for a different
# amount, and saying so should not rewrite every other week.
class TaskSeriesEdit
  SCOPES = %w[this this_and_future all].freeze

  def initialize(task, occurrence_date:)
    @task = task
    @occurrence_date = occurrence_date
  end

  # True when there is nothing before this occurrence to leave behind, which
  # makes "this and future" the same request as "all".
  def first_occurrence?
    @occurrence_date.nil? || @task.anchor_date.nil? || @task.anchor_date >= @occurrence_date
  end

  # Detaches one occurrence into a standalone task and marks the date taken.
  def detach(attributes, student_ids)
    replacement = build_copy(attributes, student_ids, completed_at: completion_at)
    return replacement unless replacement.persisted?

    consume_completion
    except_with(replacement.id)
    replacement
  end

  # Ends the original the day before and hands the rest to a new series
  # carrying the same rule, so everything after the split is an ordinary
  # series that an ordinary edit can reach.
  def split(attributes, student_ids)
    successor = build_copy(attributes, student_ids)
    return successor unless successor.persisted?

    successor.create_recurrence!(rule_attributes)
    move_later_exceptions_to(successor.recurrence)
    move_later_completions_to(successor)
    stop_original_before_the_occurrence
    successor
  end

  # Takes one occurrence out of the series without touching the rest.
  def skip
    consume_completion
    except_with(nil)
  end

  # Drops this occurrence and everything after it, leaving what came before.
  def truncate
    later_exceptions.find_each { |exception| destroy_replacement(exception) }
    later_exceptions.destroy_all
    later_completions.destroy_all
    stop_original_before_the_occurrence
  end

  # Removing a whole series takes the occurrences edited out of it as well: an
  # edited week belongs to the series a teacher is deleting. Ticks go with the
  # task through the database cascade.
  def destroy_series
    @task.recurrence&.recurrence_exceptions&.each { |exception| destroy_replacement(exception) }
    @task.destroy
  end

  private

  # Students are assigned before saving rather than after, because a task that
  # is a student's is invalid without one: assigning afterwards would let the
  # copy save and then fail the rule it exists to keep.
  def build_copy(attributes, student_ids, completed_at: nil)
    copy = @task.teacher.tasks.build(detached_attributes(attributes).merge('completed_at' => completed_at))
    copy.students = student_ids.nil? ? @task.students.to_a : @task.teacher.students.where(id: student_ids).to_a
    copy.save
    copy
  end

  # The occurrence's own date, not the series anchor's: detaching the third
  # week gives a task due that week.
  def detached_attributes(attributes)
    @task.slice(:title, :description, :owned_by)
         .merge('due_date' => @occurrence_date || @task.due_date)
         .merge(attributes.to_h.except('completed'))
  end

  # A tick already recorded against this occurrence follows it onto the
  # standalone task, so editing something already done does not untick it.
  def completion
    @completion ||= @task.task_completions.find_by(occurrence_date: @occurrence_date)
  end

  def completion_at
    completion&.completed_at
  end

  def consume_completion
    completion&.destroy
  end

  def rule_attributes
    @task.recurrence.slice(:frequency, :weekdays, :monthly_anchor, :until_date)
  end

  def except_with(replacement_id)
    @task.recurrence.recurrence_exceptions.create!(
      occurrence_date: @occurrence_date, replacement_id: replacement_id
    )
  end

  def later_exceptions
    @task.recurrence.recurrence_exceptions.on_or_after(@occurrence_date)
  end

  def later_completions
    @task.task_completions.where(occurrence_date: @occurrence_date..)
  end

  def move_later_exceptions_to(recurrence)
    later_exceptions.update_all(recurrence_id: recurrence.id)
  end

  # Ticks after the split belong to the series that now owns those dates.
  def move_later_completions_to(successor)
    later_completions.update_all(task_id: successor.id)
  end

  def stop_original_before_the_occurrence
    @task.recurrence.update!(until_date: @occurrence_date - 1)
  end

  def destroy_replacement(exception)
    return if exception.replacement_id.nil?

    Task.find_by(id: exception.replacement_id)&.destroy
  end
end
