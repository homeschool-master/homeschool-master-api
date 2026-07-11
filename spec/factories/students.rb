# frozen_string_literal: true

FactoryBot.define do
  factory :student do
    association :teacher
    first_name { 'Emma' }
    last_name { 'Masters' }
    grade_level { '5' }
    color { '#7a322d' }
    is_active { true }

    trait :with_middle_name do
      middle_name { 'Rose' }
    end
  end
end
