# frozen_string_literal: true

# The window a calendar index query covers, parsed from the two date params.
#
# Lifted out of the controller when the student filter grew: parsing is four
# methods that read as one idea and none of them are about handling a request.
#
# A bare date names one of the teacher's local days, so it widens to that day's
# bounds in their zone. A value that already carries a time is an instant the
# client chose: it is used as sent, with an explicit offset honored rather than
# reinterpreted. Either way the result converts back to UTC for the query.
class CalendarRange
  def self.call(start_date:, end_date:, time_zone:)
    new(start_date: start_date, end_date: end_date, time_zone: time_zone).call
  end

  def initialize(start_date:, end_date:, time_zone:)
    @start_date = start_date
    @end_date = end_date
    @time_zone = time_zone
  end

  # The pair of instants, or nil when either end is missing or unparseable.
  # Nil rather than an exception: a bad range is a 422 the caller renders, not
  # something to rescue at the edge of the request.
  def call
    range_start = parse_boundary(@start_date, :beginning_of_day)
    range_end = parse_boundary(@end_date, :end_of_day)
    return nil if range_start.nil? || range_end.nil?

    [range_start, range_end]
  end

  private

  def parse_boundary(value, edge)
    return nil if value.blank?

    raw = value.to_s
    raw.match?(/[T ]\d/) ? parse_instant(raw) : parse_local_day(raw, edge)
  end

  def parse_instant(raw)
    Time.zone.parse(raw)
  rescue ArgumentError
    nil
  end

  def parse_local_day(raw, edge)
    teacher_zone.parse(raw)&.public_send(edge)
  rescue ArgumentError
    nil
  end

  def teacher_zone
    ActiveSupport::TimeZone[@time_zone] || Time.zone
  end
end
