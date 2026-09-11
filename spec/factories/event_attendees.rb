# frozen_string_literal: true

FactoryBot.define do
  factory :event_attendee do
    association :calendar_event
    association :student
  end
end
