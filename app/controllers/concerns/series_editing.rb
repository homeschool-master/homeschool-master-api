# frozen_string_literal: true

# The part of the calendar events controller that is about series rather than
# about events: which occurrences an edit reaches, and how a rule is attached.
#
# Its own file because the controller was already at its length limit and
# because none of this is about handling a request: it is the calendar's three
# way choice expressed once.
module SeriesEditing
  extend ActiveSupport::Concern

  private

  # Absent means all of it, which is the only answer an ordinary event has and
  # the safe reading for a client that has not been taught the choice.
  def edit_scope
    params[:scope].presence || 'all'
  end

  def valid_scope?
    EventSeriesEdit::SCOPES.include?(edit_scope)
  end

  def render_invalid_scope
    render_error(
      'Validation failed',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: { scope: ["must be one of #{EventSeriesEdit::SCOPES.join(', ')}"] }
    )
  end

  # Showing one occurrence rebuilds just that one, so its times are the
  # occurrence's own rather than the series anchor's.
  def shown_occurrence
    return nil if @occurrence_date.nil? || !@calendar_event.recurring?

    EventOccurrences.call(@calendar_event, from: @occurrence_date, to: @occurrence_date,
                                           time_zone: current_teacher.effective_time_zone).first
  end

  def series_edit
    EventSeriesEdit.new(@calendar_event, occurrence_date: @occurrence_date,
                                         time_zone: current_teacher.effective_time_zone)
  end

  # Only a named occurrence of a real series can be edited narrowly: without a
  # date there is nothing to be "this" or to split at.
  def narrow_edit?
    @occurrence_date.present? && @calendar_event.recurring? && edit_scope != 'all'
  end

  def update_series_or_event(attendee_ids)
    return update_whole(attendee_ids) unless narrow_edit?

    editor = series_edit
    # Splitting at the first occurrence leaves nothing behind, so it is the
    # same request as editing the whole series and is answered as one.
    return update_whole(attendee_ids) if edit_scope == 'this_and_future' && editor.first_occurrence?

    render_detached(editor, attendee_ids)
  end

  def render_detached(editor, attendee_ids)
    result =
      if edit_scope == 'this'
        editor.detach(calendar_event_params, attendee_ids)
      else
        editor.split(calendar_event_params, attendee_ids)
      end

    return render_validation_errors(result) unless result.persisted?

    render_success(CalendarEventSerializer.render(result))
  end

  def update_whole(attendee_ids)
    @calendar_event.assign_attributes(calendar_event_params)
    rule = assign_rule(@calendar_event)
    return render_validation_errors(@calendar_event) unless @calendar_event.valid?
    return render_validation_errors(rule) if rule&.invalid?

    save_with_attendees(@calendar_event, attendee_ids)
    # Saving the event saves a rule it has just been given, but not changes to
    # one it already had: a has_one only autosaves a child that is new.
    rule&.save!
    render_success(CalendarEventSerializer.render(@calendar_event))
  end

  def destroy_series_or_event
    return series_edit.skip if narrow_edit? && edit_scope == 'this'
    return truncate_or_destroy if narrow_edit?
    return series_edit.destroy_series if @calendar_event.recurring?

    @calendar_event.destroy
  end

  def truncate_or_destroy
    editor = series_edit
    # Nothing survives in front of the first occurrence, so ending the series
    # there is the same as removing it.
    editor.first_occurrence? ? editor.destroy_series : editor.truncate
  end

  # nil is "leave the rule alone", an explicit null or empty object is "stop
  # repeating", and a rule replaces whatever was there.
  def assign_rule(event)
    return nil unless params.key?(:recurrence)

    rule = recurrence_params
    return event.recurrence&.destroy && nil if rule.blank?

    return event.build_recurrence(rule) if event.recurrence.nil?

    event.recurrence.assign_attributes(rule)
    event.recurrence
  end

  def recurrence_params
    return {} if params[:recurrence].blank?

    params.require(:recurrence)
          .permit(:frequency, :monthly_anchor, :until_date, weekdays: [])
          .to_h
          .compact_blank
  end
end
