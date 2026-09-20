# frozen_string_literal: true

class RecurrenceSerializer
  def self.render(recurrence)
    return nil if recurrence.nil?

    {
      frequency: recurrence.frequency,
      weekdays: recurrence.weekdays,
      monthly_anchor: recurrence.monthly_anchor,
      until_date: recurrence.until_date
    }
  end
end
