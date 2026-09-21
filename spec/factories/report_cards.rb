# frozen_string_literal: true

FactoryBot.define do
  factory :report_card do
    association :teacher
    student { association :student, teacher: teacher }
    group_id { SecureRandom.uuid }
    version { 1 }
    sequence(:title) { |n| "Autumn term #{n}" }
    period_start { Date.new(2026, 9, 1) }
    period_end { Date.new(2026, 9, 30) }
  end

  factory :report_card_entry do
    association :report_card
    subject { association :subject, teacher: report_card.teacher }
    subject_name { subject.name }
  end
end
