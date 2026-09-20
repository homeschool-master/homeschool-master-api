# frozen_string_literal: true

FactoryBot.define do
  factory :task_student do
    association :task
    association :student
  end
end
