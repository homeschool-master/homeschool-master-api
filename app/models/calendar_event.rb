# frozen_string_literal: true

class CalendarEvent < ApplicationRecord
  # Callbacks
  before_validation :default_created_time_zone, on: :create

  # Associations
  belongs_to :teacher

  has_many :event_attendees, dependent: :destroy
  has_many :students, through: :event_attendees

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
  scope :for_student, ->(student_id) { joins(:event_attendees).where(event_attendees: { student_id: student_id }) }
  scope :chronological, -> { order(start_time: :asc) }

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
