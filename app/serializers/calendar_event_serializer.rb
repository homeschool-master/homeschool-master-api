# frozen_string_literal: true

class CalendarEventSerializer
  def self.render(calendar_event)
    new(calendar_event).to_h
  end

  def initialize(calendar_event)
    @calendar_event = calendar_event
  end

  def to_h # rubocop:disable Metrics/MethodLength
    {
      id: @calendar_event.id,
      teacher_id: @calendar_event.teacher_id,
      title: @calendar_event.title,
      notes: @calendar_event.notes,
      location: @calendar_event.location,
      start_time: @calendar_event.start_time,
      end_time: @calendar_event.end_time,
      all_day: @calendar_event.all_day,
      created_time_zone: @calendar_event.created_time_zone,
      attendees: attendees,
      created_at: @calendar_event.created_at
    }
  end

  private

  def attendees
    @calendar_event.students.map { |student| StudentSerializer.render(student) }
  end
end
