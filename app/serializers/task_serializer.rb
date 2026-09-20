# frozen_string_literal: true

class TaskSerializer
  # An occurrence has no row of its own, so it has no id of its own. It is
  # named by the series it came from and the local date it falls on, joined
  # into one opaque string the client hands straight back: "<uuid>:<date>".
  # An ordinary task keeps its bare uuid, so nothing created before this
  # feature has to be told apart from anything else. Same format the calendar
  # uses, because it is the same idea.
  OCCURRENCE_SEPARATOR = ':'

  def self.render(task, occurrence: nil)
    new(task, occurrence: occurrence).to_h
  end

  # Splits a client supplied id back into the series id and the occurrence
  # date. A bare uuid parses as itself with no date, which is how one route
  # accepts both.
  def self.parse_id(value)
    id, date = value.to_s.split(OCCURRENCE_SEPARATOR, 2)
    [id, parse_date(date)]
  end

  def self.parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue Date::Error
    nil
  end

  def initialize(task, occurrence: nil)
    @task = task
    @occurrence = occurrence
  end

  def to_h
    base.merge(recurrence_fields)
  end

  private

  # Both faces of completion: the boolean a checkbox binds to, and the instant
  # it was ticked. For an ordinary task those come from the row's own column.
  # For an occurrence they come from its tick, so ticking one week leaves the
  # rest of the series exactly as it was.
  #
  # student_ids and owned_by answer two different questions and both are sent:
  # who the task concerns, and whose job it is.
  def base # rubocop:disable Metrics/MethodLength
    {
      id: id,
      teacher_id: @task.teacher_id,
      title: @task.title,
      description: @task.description,
      due_date: due_date,
      completed: completed,
      completed_at: completed_at,
      owned_by: @task.owned_by,
      student_ids: @task.student_ids,
      created_at: @task.created_at
    }
  end

  # series_id and occurrence_date ride beside the composite id rather than
  # leaving the client to split it: the id is its handle, these two are what it
  # needs to decide whether to offer "this occurrence" or not.
  def recurrence_fields
    {
      series_id: @occurrence ? @task.id : nil,
      occurrence_date: @occurrence&.date,
      recurrence: RecurrenceSerializer.render(@task.recurrence)
    }
  end

  def id
    return @task.id if @occurrence.nil?

    "#{@task.id}#{OCCURRENCE_SEPARATOR}#{@occurrence.date}"
  end

  def due_date
    @occurrence ? @occurrence.date : @task.due_date
  end

  def completed
    @occurrence ? @occurrence.completed : @task.completed
  end

  def completed_at
    @occurrence ? @occurrence.completed_at : @task.completed_at
  end
end
