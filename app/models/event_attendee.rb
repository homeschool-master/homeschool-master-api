# frozen_string_literal: true

class EventAttendee < ApplicationRecord
  # Associations
  belongs_to :calendar_event
  belongs_to :student

  # Validations
  validates :student_id, uniqueness: { scope: :calendar_event_id, message: 'is already an attendee of this event' }
end
