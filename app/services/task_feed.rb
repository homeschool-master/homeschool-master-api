# frozen_string_literal: true

# What the tasks index answers with: the ordinary tasks, plus every occurrence
# the repeating ones produce inside a window, in one ordered list.
#
# The two are queried separately because they are two different questions.
#
# **The window bounds the expansion, not the list.** An ordinary task is one
# row and is returned whatever its due date, exactly as it always was: a task
# due next year has not gone anywhere. A series has no rows to return, so it
# has to be expanded, and expanding forever is not possible: those are fetched
# by the coarse test of "could reach" and walked over the window the caller
# asked for.
class TaskFeed
  Entry = Struct.new(:task, :occurrence, keyword_init: true) do
    def due_date
      occurrence ? occurrence.date : task.due_date
    end

    # Named to match Task#completed, so a row and an occurrence answer the
    # same question the same way.
    def completed
      occurrence ? occurrence.completed : task.completed
    end

    def completed_at
      occurrence ? occurrence.completed_at : task.completed_at
    end
  end

  def self.call(teacher:, from:, to:, scope: nil)
    new(teacher: teacher, from: from, to: to, scope: scope).call
  end

  def initialize(teacher:, from:, to:, scope: nil)
    @teacher = teacher
    @from = from
    @to = to
    @scope = scope || teacher.tasks
  end

  # Soonest first, undated last, creation order for ties: the same order the
  # index has always used, now applied to occurrences as well as rows.
  def call
    (single_entries + series_entries).sort_by do |entry|
      [entry.due_date.nil? ? 1 : 0, entry.due_date || Date.new(9999, 12, 31), entry.task.created_at]
    end
  end

  private

  # Every ordinary task, dated or not, in or out of the window. Narrowing them
  # is what the due_by filter is for, and it is asked for rather than implied.
  def single_entries
    @scope.single.map { |task| Entry.new(task: task, occurrence: nil) }
  end

  def series_entries
    @scope.series_reaching(@to, @from)
          .includes(:task_completions, recurrence: :recurrence_exceptions)
          .flat_map { |task| entries_for(task) }
  end

  def entries_for(task)
    TaskOccurrences.call(task, from: @from, to: @to)
                   .map { |occurrence| Entry.new(task: task, occurrence: occurrence) }
  end
end
