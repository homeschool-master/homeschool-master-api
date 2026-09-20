# frozen_string_literal: true

FactoryBot.define do
  factory :recurrence do
    association :recurrable, factory: :calendar_event
    frequency { 'weekly' }
    weekdays { [2] }
    monthly_anchor { nil }
    until_date { nil }

    trait :daily do
      frequency { 'daily' }
      weekdays { [] }
    end

    trait :monthly_by_date do
      frequency { 'monthly' }
      weekdays { [] }
      monthly_anchor { 'day_of_month' }
    end

    trait :monthly_by_position do
      frequency { 'monthly' }
      weekdays { [] }
      monthly_anchor { 'weekday_position' }
    end

    trait :yearly do
      frequency { 'yearly' }
      weekdays { [] }
    end
  end
end
