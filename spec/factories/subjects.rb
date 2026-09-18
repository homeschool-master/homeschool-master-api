# frozen_string_literal: true

FactoryBot.define do
  factory :subject do
    association :teacher
    sequence(:name) { |n| "Subject #{n}" }
    color { '#d97b0a' }
    description { 'Weekly lessons and practice' }
    is_active { true }
  end
end
