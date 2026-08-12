# frozen_string_literal: true

FactoryBot.define do
  factory :refresh_token do
    association :teacher
    sequence(:token) { |n| "refresh-token-#{n}" }
    sequence(:jti) { |n| "jti-#{n}" }
    expires_at { 7.days.from_now }
    revoked_at { nil }

    trait :revoked do
      revoked_at { Time.current }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
