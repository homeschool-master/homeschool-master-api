# frozen_string_literal: true

FactoryBot.define do
  factory :assignment do
    association :teacher
    subject { association :subject, teacher: teacher }
    # Every teacher is created with the three built in types, so the ordinary
    # one is already there to point at rather than being built a second time.
    assignment_type { teacher.assignment_types.find_by(name: 'Assignment') }
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
