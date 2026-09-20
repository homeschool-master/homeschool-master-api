# frozen_string_literal: true

class CalendarEvent < ApplicationRecord
  # Callbacks
  before_validation :default_created_time_zone, on: :create

  # Associations
  belongs_to :teacher

  has_many :event_attendees, dependent: :destroy
  has_many :students, through: :event_attendees

  # A series carries its rule; an ordinary event has none, which is what keeps
  # every event created before this feature working untouched.
  has_one :recurrence, as: :recurrable, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time
  validates :created_time_zone, iana_time_zone: true

  # Scopes
  # Overlap semantics: an event counts as in range when any part of it falls
  # inside the window, so a multi day event still shows on a week that it
  # straddles.
  scope :in_range, lambda { |range_start, range_end|
    where(start_time: ..range_end).where(end_time: range_start..)
  }
  # Any of them, not all of them: a lesson two children sit together belongs
  # on both their calendars, and asking for the pair means either, not the
  # intersection. distinct because the join repeats an event once per selected
  # attendee it has.
  scope :for_students, lambda { |student_ids|
    joins(:event_attendees).where(event_attendees: { student_id: student_ids }).distinct
  }
  scope :chronological, -> { order(start_time: :asc) }

  # Events that repeat, and events that do not. Every query has to serve both:
  # one row stands for itself, the other stands for a series that is expanded.
  scope :single, -> { where.missing(:recurrence) }
  scope :series, -> { where.associated(:recurrence) }
  # A series can reach a window when it starts on or before the end of it and
  # has not already finished by the start of it. Whether it actually lands in
  # the window is the schedule's business, not the query's.
  scope :series_reaching, lambda { |range_end, local_from|
    series.where(start_time: ..range_end)
          .where('recurrences.until_date IS NULL OR recurrences.until_date >= ?', local_from)
  }

  def recurring?
    recurrence.present?
  end

  private

  # Records the zone the event was created in. Nothing reads it yet: it is the
  # input a later floating versus absolute event decision will need. A blank
  # value falls back to the teacher's zone, but a value the client did send is
  # left alone so an invalid one fails validation instead of being replaced.
  def default_created_time_zone
    self.created_time_zone = teacher&.effective_time_zone if created_time_zone.blank?
  end

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, 'must be after the start time') if end_time <= start_time
  end
end
