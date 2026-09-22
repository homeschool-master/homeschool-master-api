# frozen_string_literal: true

# Editing and deleting one occurrence of a series, in the three ways a
# calendar offers: this occurrence, this and everything after it, or all of it.
#
# "This occurrence" detaches. The occurrence becomes an ordinary standalone
# event and the series records an exception naming the date and the row that
# stands in for it. The detached event keeps its own attendees and is edited
# and deleted like any other, which is the point: one edited Tuesday should
# not need a second kind of event to exist.
#
# "This and future" splits. The original series is told to stop the day before,
# and a second series starts at the occurrence carrying the edits. Splitting
# rather than storing a second rule against one row means every later edit is
# an ordinary edit of an ordinary series, and the history before the split is
# left exactly as it was.
class EventSeriesEdit
  SCOPES = %w[this this_and_future all].freeze

  def initialize(event, occurrence_date:, time_zone:)
    @event = event
    @occurrence_date = occurrence_date
    @time_zone = time_zone
  end

  # True when there is nothing before this occurrence to leave behind, which
  # makes "this and future" the same request as "all".
  def first_occurrence?
    @occurrence_date.nil? ||
      EventOccurrences.new(@event, time_zone: @time_zone).anchor_date >= @occurrence_date
  end

  # Detaches one occurrence into a standalone event and marks the date taken.
  def detach(attributes, student_ids)
    replacement = build_copy(attributes, student_ids)
    return replacement unless replacement.persisted?

    DocumentAttachment.move_occurrence(@event, replacement, @occurrence_date)
    except_with(replacement.id)
    replacement
  end

  # Ends the original at the day before and hands the rest to a new series
  # carrying the same rule, so everything after the split is an ordinary
  # series that an ordinary edit can reach.
  def split(attributes, student_ids)
    successor = build_copy(attributes, student_ids)
    return successor unless successor.persisted?

    successor.create_recurrence!(rule_attributes)
    move_later_exceptions_to(successor.recurrence)
    DocumentAttachment.move_occurrences_from(@event, successor, @occurrence_date)
    stop_original_before_the_occurrence
    successor
  end

  # Takes one occurrence out of the series without touching the rest.
  def skip
    except_with(nil)
  end

  # Drops this occurrence and everything after it, leaving what came before.
  def truncate
    later_exceptions.find_each { |exception| destroy_replacement(exception) }
    later_exceptions.destroy_all
    stop_original_before_the_occurrence
  end

  # Removing a whole series takes the occurrences edited out of it as well: an
  # edited Tuesday belongs to the series a teacher is deleting.
  def destroy_series
    @event.recurrence&.recurrence_exceptions&.each { |exception| destroy_replacement(exception) }
    @event.destroy
  end

  private

  # Attendees are assigned after saving, because a has_many through cannot be
  # written on a row that does not exist yet. Unsubmitted means "the same
  # people as the series", which is what editing one Tuesday implies.
  def build_copy(attributes, student_ids)
    copy = @event.teacher.calendar_events.build(detached_attributes(attributes))
    return copy unless copy.save

    copy.student_ids = student_ids.nil? ? @event.student_ids : student_ids
    copy.students.reload
    copy
  end

  def detached_attributes(attributes)
    @event.slice(:title, :notes, :location, :all_day, :created_time_zone)
          .merge('start_time' => occurrence_start, 'end_time' => occurrence_end)
          .merge(attributes.to_h)
  end

  def occurrence_times
    @occurrence_times ||=
      EventOccurrences.call(@event, from: @occurrence_date, to: @occurrence_date,
                                    time_zone: @time_zone).first
  end

  def occurrence_start
    occurrence_times&.start_time || @event.start_time
  end

  def occurrence_end
    occurrence_times&.end_time || @event.end_time
  end

  def rule_attributes
    @event.recurrence.slice(:frequency, :weekdays, :monthly_anchor, :until_date)
  end

  def except_with(replacement_id)
    @event.recurrence.recurrence_exceptions.create!(
      occurrence_date: @occurrence_date, replacement_id: replacement_id
    )
  end

  def later_exceptions
    @event.recurrence.recurrence_exceptions.on_or_after(@occurrence_date)
  end

  def move_later_exceptions_to(recurrence)
    later_exceptions.update_all(recurrence_id: recurrence.id)
  end

  def stop_original_before_the_occurrence
    @event.recurrence.update!(until_date: @occurrence_date - 1)
  end

  def destroy_replacement(exception)
    return if exception.replacement_id.nil?

    CalendarEvent.find_by(id: exception.replacement_id)&.destroy
  end
end
