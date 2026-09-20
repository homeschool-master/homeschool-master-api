# frozen_string_literal: true

# What the calendar index answers with: the ordinary events inside a window,
# plus every occurrence the recurring ones produce in it, in one ordered list.
#
# The two are queried separately because they are two different questions. An
# ordinary event is in range when its own times overlap the window. A series is
# in range when the rule lands inside it, which no SQL predicate on start_time
# can answer, so those rows are fetched by the coarse test of "could reach"
# and expanded in Ruby over a window that is already bounded by the screen.
class CalendarEventFeed
  Entry = Struct.new(:event, :occurrence, keyword_init: true) do
    def start_time
      occurrence ? occurrence.start_time : event.start_time
    end
  end

  def self.call(teacher:, range:, student_ids: [])
    new(teacher: teacher, range: range, student_ids: student_ids).call
  end

  def initialize(teacher:, range:, student_ids: [])
    @teacher = teacher
    @range = range
    @student_ids = student_ids
  end

  def call
    (single_entries + series_entries).sort_by(&:start_time)
  end

  private

  def zone
    @zone ||= ActiveSupport::TimeZone[@teacher.effective_time_zone] || Time.zone
  end

  # The window as the teacher's own days, which is what a series is expanded
  # over: a month on screen is a span of local dates, not of UTC instants.
  def local_from
    @local_from ||= @range.first.in_time_zone(zone).to_date
  end

  def local_to
    @local_to ||= @range.last.in_time_zone(zone).to_date
  end

  def scoped
    events = @teacher.calendar_events.includes(:students)
    @student_ids.empty? ? events : events.for_students(@student_ids)
  end

  def single_entries
    scoped.single.in_range(*@range).map { |event| Entry.new(event: event, occurrence: nil) }
  end

  def series_entries
    scoped.series_reaching(@range.last, local_from).includes(recurrence: :recurrence_exceptions)
          .flat_map { |event| entries_for(event) }
  end

  def entries_for(event)
    EventOccurrences
      .call(event, from: local_from, to: local_to, time_zone: @teacher.effective_time_zone)
      .map { |occurrence| Entry.new(event: event, occurrence: occurrence) }
  end
end
