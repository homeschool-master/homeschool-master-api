# frozen_string_literal: true

# Turns a repeat rule plus an anchor date into the dates it produces inside a
# window. Dates only, in the owner's own local calendar: an event turns each
# date into a pair of instants in the teacher's zone and a task turns it into a
# due date, so neither of those decisions belongs here.
#
# Nothing is stored. A window is always bounded by what the caller asked for,
# so an endless weekly series costs one pass over the days on screen.
#
# **Months that do not contain the anchor are skipped, not clamped.** A series
# on the fifth Friday has no occurrence in a month with four Fridays, and one
# on the 31st has none in September. Clamping backwards would move the
# occurrence into a week or a day the teacher did not pick, and would land it
# on top of whatever they did pick there.
class RecurrenceSchedule
  def initialize(recurrence, start_date:)
    @recurrence = recurrence
    @start_date = start_date
  end

  # Inclusive at both ends, ordered, and never before the series starts or
  # after it ends.
  def dates_between(from, to)
    lower = [from, @start_date].max
    upper = @recurrence.until_date ? [to, @recurrence.until_date].min : to
    return [] if lower > upper

    case @recurrence.frequency
    when 'daily' then (lower..upper).to_a
    when 'weekly' then weekly_dates(lower, upper)
    when 'monthly' then anchored_dates(lower, upper, :next_month)
    when 'yearly' then anchored_dates(lower, upper, :next_year)
    else []
    end
  end

  private

  # Several days at once, so "every Tuesday and Thursday" is one series. A rule
  # that names none falls back to the day the series starts on, which is what
  # a weekly repeat means with nothing else said.
  def weekly_dates(lower, upper)
    days = @recurrence.weekdays.presence || [@start_date.wday]
    (lower..upper).select { |date| days.include?(date.wday) }
  end

  # Monthly and yearly differ only in how far the cursor steps.
  def anchored_dates(lower, upper, step)
    results = []
    cursor = Date.new(lower.year, lower.month, 1)
    cursor = Date.new(lower.year, @start_date.month, 1) if step == :next_year

    while cursor <= upper
      date = anchor_in(cursor)
      results << date if date&.between?(lower, upper) && date >= @start_date
      cursor = cursor.public_send(step)
    end

    results
  end

  def anchor_in(month)
    return nth_weekday(month) if @recurrence.monthly_anchor == 'weekday_position'

    on(month.year, month.month, @start_date.day)
  end

  # The same weekday position the series started on: a series beginning on the
  # third Friday lands on the third Friday, and returns nothing for a month
  # without one.
  def nth_weekday(month)
    first = Date.new(month.year, month.month, 1)
    offset = (@start_date.wday - first.wday) % 7

    on(month.year, month.month, 1 + offset + ((week_position - 1) * 7))
  end

  def week_position
    ((@start_date.day - 1) / 7) + 1
  end

  def on(year, month, day)
    Date.valid_date?(year, month, day) ? Date.new(year, month, day) : nil
  end
end
