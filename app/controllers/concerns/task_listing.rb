# frozen_string_literal: true

# How the tasks index narrows a list: the window a series is expanded over,
# and the filters applied to what comes back.
#
# Its own file because it is a different idea from handling a task. The
# controller answers "what is this request about"; this answers "how much of
# the list does it want".
module TaskListing
  extend ActiveSupport::Concern

  # How far a list reaches when the client does not say. A repeating task
  # produces occurrences forever, so something has to bound the expansion: far
  # enough back to still show what is overdue, far enough forward to plan with,
  # and overridable by anything that wants a different window.
  DEFAULT_DAYS_BACK = 30
  DEFAULT_DAYS_AHEAD = 60

  private

  # The filters read the entry rather than the row, because what a teacher
  # ticks and what is due is an occurrence, not a series.
  def filtered_entries(entries)
    entries = apply_completed_filter(entries)
    return entries if performed?

    apply_due_by_filter(entries)
  end

  def apply_completed_filter(entries)
    return entries if params[:completed].blank?

    case params[:completed]
    when 'true' then entries.select(&:completed)
    when 'false' then entries.reject(&:completed)
    else render_invalid_filter('completed', 'must be true or false')
    end
  end

  def apply_due_by_filter(entries)
    return entries if params[:due_by].blank?

    date = parse_filter_date(params[:due_by])
    return render_invalid_filter('due_by', 'must be a valid date') if date.nil?

    entries.select { |entry| entry.due_date.present? && entry.due_date <= date }
  end

  # The window the series are expanded over. due_by narrows the far end, since
  # nothing after it could satisfy that filter anyway.
  def parsed_window
    from = window_bound(:from, Date.current - DEFAULT_DAYS_BACK)
    return if performed?

    to = window_bound(:to, Date.current + DEFAULT_DAYS_AHEAD)
    return if performed?

    due_by = params[:due_by].present? ? parse_filter_date(params[:due_by]) : nil
    [from, [to, due_by].compact.min]
  end

  def window_bound(field, fallback)
    return fallback if params[field].blank?

    parsed = parse_filter_date(params[field])
    return render_invalid_filter(field.to_s, 'must be a valid date') if parsed.nil?

    parsed
  end

  def parse_filter_date(value)
    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end

  # A filter that cannot be honored is an error rather than something to drop
  # quietly: a dashboard silently showing every task would look like it was
  # working.
  def render_invalid_filter(field, message)
    render_error(
      'Validation failed',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: { field => [message] }
    )
    nil
  end
end
