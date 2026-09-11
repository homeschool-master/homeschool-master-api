# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_event do
    association :teacher
    title { 'Math Lesson' }
    notes { 'Chapter 4 review' }
    location { 'Kitchen table' }
    start_time { Time.utc(2026, 9, 15, 14, 0, 0) }
    end_time { Time.utc(2026, 9, 15, 15, 0, 0) }
    all_day { false }

    trait :all_day do
      all_day { true }
      start_time { Time.utc(2026, 9, 15, 0, 0, 0) }
      end_time { Time.utc(2026, 9, 15, 23, 59, 59) }
    end
  end
end
