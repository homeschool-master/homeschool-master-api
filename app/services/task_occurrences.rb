# frozen_string_literal: true

# Turns a repeating task into the occurrences it produces in a window.
#
# The seam between a task and an event is exactly here and nowhere else. The
# rule and its dates are shared: RecurrenceSchedule answers both. An event then
# turns each date into a pair of instants in the teacher's zone, because a
# lesson happens at a time. A task turns each date into a due date and stops,
# because a to-do is due on a day. So this class has no zone in it at all,
# which is the whole difference.
class TaskOccurrences
  # completed_at is the tick recorded against this occurrence, or nil. It is
  # carried here rather than looked up per row, so a window costs one query.
  Occurrence = Struct.new(:date, :completed_at, keyword_init: true) do
    # Named to match Task#completed rather than as a predicate, so the feed and
    # the serializer can ask a row and an occurrence the same question. Same
    # reasoning, and the same cop, as the model's own reader.
    # rubocop:disable Naming/PredicateMethod
    def completed
      completed_at.present?
    end
    # rubocop:enable Naming/PredicateMethod
  end

  def self.call(task, from:, to:)
    new(task).between(from, to)
  end

  def initialize(task)
    @task = task
  end

  def between(from, to)
    return [] if @task.recurrence.nil? || @task.anchor_date.nil?

    @task.recurrence
         .dates_between(@task.anchor_date, from, to)
         .reject { |date| excepted_dates.include?(date) }
         .map { |date| Occurrence.new(date: date, completed_at: completions[date]) }
  end

  # An occurrence that was edited or deleted does not come from the rule. A
  # deleted one is simply gone; an edited one is a standalone task that the
  # feed returns on its own account, so either way the rule must not also
  # produce it.
  def excepted_dates
    @excepted_dates ||= @task.recurrence.recurrence_exceptions.pluck(:occurrence_date).to_set
  end

  private

  def completions
    @completions ||= @task.task_completions.pluck(:occurrence_date, :completed_at).to_h
  end
end
