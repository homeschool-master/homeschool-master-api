# frozen_string_literal: true

# How something repeats. One row per series, never one per occurrence.
#
# Deliberately not a full RRULE: frequency, which weekdays, which monthly
# anchor, and when it stops. No interval, because "every other Tuesday" is a
# different feature and every field here has to be answerable by a control on
# a form a parent fills in.
class Recurrence < ApplicationRecord
  FREQUENCIES = %w[daily weekly monthly yearly].freeze
  MONTHLY_ANCHORS = %w[day_of_month weekday_position].freeze

  # Associations
  belongs_to :recurrable, polymorphic: true
  has_many :recurrence_exceptions, dependent: :destroy

  # Validations
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :monthly_anchor, inclusion: { in: MONTHLY_ANCHORS }, if: :monthly?
  validate :weekdays_are_days_of_the_week
  validate :weekly_names_at_least_one_day

  def weekly?
    frequency == 'weekly'
  end

  def monthly?
    frequency == 'monthly'
  end

  # The dates this rule produces in a window, which is the whole of what
  # events and tasks share: an event turns a date into a pair of instants in
  # the teacher's zone, a task turns it into a due date, and neither of those
  # belongs here.
  def dates_between(start_date, from, to)
    RecurrenceSchedule.new(self, start_date: start_date).dates_between(from, to)
  end

  private

  def weekdays_are_days_of_the_week
    return if weekdays.blank?
    return if weekdays.all? { |day| day.is_a?(Integer) && day.between?(0, 6) }

    errors.add(:weekdays, 'must be days of the week, 0 for Sunday through 6 for Saturday')
  end

  def weekly_names_at_least_one_day
    return unless weekly?
    return if weekdays.present?

    errors.add(:weekdays, 'must name at least one day for a weekly series')
  end
end
