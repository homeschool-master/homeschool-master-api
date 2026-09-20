# frozen_string_literal: true

# Turns a recurring event into the occurrences it produces in a window.
#
# **Expansion happens in the teacher's zone, not in UTC.** A weekly event at
# 3pm is 3pm every week, and between March and November that is two different
# UTC instants. Adding seven days to a UTC timestamp would hold the UTC hour
# still and walk the local one, moving every lesson by an hour twice a year.
# So each occurrence is rebuilt from the wall clock: the same hour and minute
# on its own date in the teacher's zone, converted back to UTC afterwards.
#
# The length is carried across rather than the finishing wall clock, which is
# what a calendar means by an event's duration and is the only reading that
# survives an occurrence straddling the change itself.
class EventOccurrences
  Occurrence = Struct.new(:date, :start_time, :end_time, keyword_init: true)

  def self.call(event, from:, to:, time_zone:)
    new(event, time_zone: time_zone).between(from, to)
  end

  def initialize(event, time_zone:)
    @event = event
    @zone = ActiveSupport::TimeZone[time_zone] || Time.zone
  end

  # from and to are local dates, because a window on a calendar is a span of
  # the teacher's days rather than of UTC instants.
  def between(from, to)
    return [] if @event.recurrence.nil?

    @event.recurrence
          .dates_between(anchor_date, from, to)
          .reject { |date| excepted_dates.include?(date) }
          .map { |date| occurrence_on(date) }
  end

  # The day the series starts, read in the teacher's zone: an event at 8pm
  # Pacific is already tomorrow in UTC, and the series follows the local day.
  def anchor_date
    local_start.to_date
  end

  # An occurrence that was edited or deleted does not come from the rule. A
  # deleted one is simply gone; an edited one is a standalone row that the
  # feed returns on its own account, so either way the rule must not also
  # produce it.
  def excepted_dates
    @excepted_dates ||= @event.recurrence.recurrence_exceptions.pluck(:occurrence_date).to_set
  end

  private

  def local_start
    @local_start ||= @event.start_time.in_time_zone(@zone)
  end

  def occurrence_on(date)
    start_at = @zone.local(date.year, date.month, date.day,
                           local_start.hour, local_start.min, local_start.sec)

    Occurrence.new(date: date, start_time: start_at.utc, end_time: (start_at + duration).utc)
  end

  def duration
    @duration ||= @event.end_time - @event.start_time
  end
end
