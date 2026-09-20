# frozen_string_literal: true

# The part of a controller that is about series rather than about the thing
# that repeats: which occurrences an edit reaches, and how a rule is attached.
#
# Shared by calendar events and tasks, because the three way choice is the same
# choice for both and should not exist twice. What differs between them is
# supplied by the five hooks below: which record is being edited, which editor
# knows how to detach and split it, which params it permits, how it is
# rendered, and how a whole record update is applied. Everything else,
# including what "this and future" means at the very first occurrence, is the
# same for a lesson and a to-do.
module SeriesEditing
  extend ActiveSupport::Concern

  private

  # Hooks. Each including controller answers these for its own kind.
  def series_record
    raise NotImplementedError
  end

  def series_editor
    raise NotImplementedError
  end

  def series_params
    raise NotImplementedError
  end

  def render_series(record)
    raise NotImplementedError
  end

  # Applies an edit that reaches the whole record, returning whether it saved.
  # Left to the controller because assigning members differs: an event writes
  # its attendees after saving, a task has to have its students before it is
  # valid at all.
  def apply_whole_update(_members)
    raise NotImplementedError
  end

  # Absent means all of it, which is the only answer an ordinary record has and
  # the safe reading for a client that has not been taught the choice.
  def edit_scope
    params[:scope].presence || 'all'
  end

  def series_scopes
    series_editor.class::SCOPES
  end

  def valid_scope?
    series_scopes.include?(edit_scope)
  end

  def render_invalid_scope
    render_error(
      'Validation failed',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: { scope: ["must be one of #{series_scopes.join(', ')}"] }
    )
  end

  # Only a named occurrence of a real series can be edited narrowly: without a
  # date there is nothing to be "this" or to split at.
  def narrow_edit?
    @occurrence_date.present? && series_record.recurring? && edit_scope != 'all'
  end

  def update_series_or_record(members)
    return update_whole(members) unless narrow_edit?

    editor = series_editor
    # Splitting at the first occurrence leaves nothing behind, so it is the
    # same request as editing the whole series and is answered as one.
    return update_whole(members) if edit_scope == 'this_and_future' && editor.first_occurrence?

    render_detached(editor, members)
  end

  def render_detached(editor, members)
    result =
      if edit_scope == 'this'
        editor.detach(series_params, members)
      else
        editor.split(series_params, members)
      end

    return render_validation_errors(result) unless result.persisted?

    render_success(render_series(result))
  end

  def update_whole(members)
    return unless apply_whole_update(members)

    render_success(render_series(series_record))
  end

  def destroy_series_or_record
    return series_editor.skip if narrow_edit? && edit_scope == 'this'
    return truncate_or_destroy if narrow_edit?
    return series_editor.destroy_series if series_record.recurring?

    series_record.destroy
  end

  def truncate_or_destroy
    editor = series_editor
    # Nothing survives in front of the first occurrence, so ending the series
    # there is the same as removing it.
    editor.first_occurrence? ? editor.destroy_series : editor.truncate
  end

  # nil is "leave the rule alone", an explicit null or empty object is "stop
  # repeating", and a rule replaces whatever was there.
  def assign_rule(record)
    return nil unless params.key?(:recurrence)

    rule = recurrence_params
    return stop_repeating(record) if rule.blank?

    return record.build_recurrence(rule) if record.recurrence.nil?

    record.recurrence.assign_attributes(rule)
    record.recurrence
  end

  # Destroying the rule leaves the association still holding the destroyed
  # object, so anything asking afterwards whether the record still repeats gets
  # the wrong answer. Reloading is what makes "it no longer repeats" true.
  def stop_repeating(record)
    existing = record.recurrence
    return nil if existing.nil?

    existing.destroy
    record.reload_recurrence
    nil
  end

  def recurrence_params
    return {} if params[:recurrence].blank?

    params.require(:recurrence)
          .permit(:frequency, :monthly_anchor, :until_date, weekdays: [])
          .to_h
          .compact_blank
  end
end
