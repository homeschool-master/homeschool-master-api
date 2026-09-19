# frozen_string_literal: true

FactoryBot.define do
  factory :assignment do
    association :teacher
    subject { association :subject, teacher: teacher }
    sequence(:title) { |n| "Assignment #{n}" }
    due_date { Date.new(2026, 9, 20) }
    points_possible { 100 }
    weight { 1 }
  end

  factory :assignment_grade do
    association :assignment
    student { association :student, teacher: assignment.teacher }
    points_earned { nil }
  end
end
