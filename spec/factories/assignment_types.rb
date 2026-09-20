# frozen_string_literal: true

FactoryBot.define do
  # A teacher's own type. The three built in ones are created with the teacher,
  # so this factory makes the custom kind by default.
  factory :assignment_type do
    association :teacher
    sequence(:name) { |n| "Narration #{n}" }
    default_weight { 1 }
    is_built_in { false }
  end
end
