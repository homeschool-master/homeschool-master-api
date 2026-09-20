# frozen_string_literal: true

class CalendarEventSerializer
  # An occurrence has no row of its own, so it has no id of its own. It is
  # named by the series it came from and the local date it falls on, joined
  # into one opaque string the client can hand straight back: "<uuid>:<date>".
  # An ordinary event keeps its bare uuid, so nothing created before this
  # feature has to be told apart from anything else.
  OCCURRENCE_SEPARATOR = ':'

  def self.render(calendar_event, occurrence: nil)
    new(calendar_event, occurrence: occurrence).to_h
  end

  # Splits a client supplied id back into the series id and the occurrence
  # date. A bare uuid parses as itself with no date, which is how the routes
  # accept both without two of everything.
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

  def initialize(calendar_event, occurrence: nil)
    @calendar_event = calendar_event
    @occurrence = occurrence
  end

  def to_h
    base.merge(recurrence_fields)
  end

  private

  def base # rubocop:disable Metrics/MethodLength
    {
      id: id,
      teacher_id: @calendar_event.teacher_id,
      title: @calendar_event.title,
      notes: @calendar_event.notes,
      location: @calendar_event.location,
      start_time: start_time,
      end_time: end_time,
      all_day: @calendar_event.all_day,
      created_time_zone: @calendar_event.created_time_zone,
      attendee_ids: @calendar_event.student_ids,
      created_at: @calendar_event.created_at
    }
  end

  # series_id and occurrence_date are sent beside the composite id rather than
  # leaving the client to split it: the id is the client's handle, these two
  # are what it needs to decide whether to offer "this occurrence" or not.
  def recurrence_fields
    {
      series_id: @occurrence ? @calendar_event.id : nil,
      occurrence_date: @occurrence&.date,
      recurrence: RecurrenceSerializer.render(@calendar_event.recurrence)
    }
  end

  def id
    return @calendar_event.id if @occurrence.nil?

    "#{@calendar_event.id}#{OCCURRENCE_SEPARATOR}#{@occurrence.date}"
  end

  def start_time
    @occurrence ? @occurrence.start_time : @calendar_event.start_time
  end

  def end_time
    @occurrence ? @occurrence.end_time : @calendar_event.end_time
  end
end
