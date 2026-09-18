# frozen_string_literal: true

FactoryBot.define do
  factory :task do
    association :teacher
    sequence(:title) { |n| "Task #{n}" }
    description { 'Notes about the task' }
    due_date { Date.new(2026, 9, 25) }
    completed_at { nil }

    trait :completed do
      completed_at { Time.utc(2026, 9, 18, 12, 0, 0) }
    end

    trait :undated do
      due_date { nil }
    end
  end
end
