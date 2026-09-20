# frozen_string_literal: true

# How a calendar event behaves as a series: the hooks SeriesEditing asks for,
# answered in the calendar's terms, and the rebuilding of a single occurrence
# for the detail view.
#
# Its own file for the same reason TaskSeries is: none of it is about handling
# a request, and the controller was at its length limit without it.
module CalendarSeries
  extend ActiveSupport::Concern

  private

  # The hooks SeriesEditing asks for, answered in the calendar's terms.
  def series_record
    @calendar_event
  end

  def series_editor
    EventSeriesEdit.new(@calendar_event, occurrence_date: @occurrence_date,
                                         time_zone: current_teacher.effective_time_zone)
  end

  def series_params
    calendar_event_params
  end

  def render_series(record)
    CalendarEventSerializer.render(record)
  end

  # Attendees are written after saving, which a has_many through on a new
  # row requires, so the rule is saved alongside rather than relying on the
  # event's own autosave: a has_one only autosaves a child that is new.
  def apply_whole_update(attendee_ids)
    @calendar_event.assign_attributes(calendar_event_params)
    rule = assign_rule(@calendar_event)
    return render_validation_errors(@calendar_event) && false unless @calendar_event.valid?
    return render_validation_errors(rule) && false if rule&.invalid?

    save_with_attendees(@calendar_event, attendee_ids)
    rule&.save!
    true
  end

  # Showing one occurrence rebuilds just that one, so its times are the
  # occurrence's own rather than the series anchor's.
  def shown_occurrence
    return nil if @occurrence_date.nil? || !@calendar_event.recurring?

    EventOccurrences.call(@calendar_event, from: @occurrence_date, to: @occurrence_date,
                                           time_zone: current_teacher.effective_time_zone).first
  end
end
