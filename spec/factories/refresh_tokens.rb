# frozen_string_literal: true

FactoryBot.define do
  factory :refresh_token do
    teacher { nil }
    token { 'MyString' }
    jti { 'MyString' }
    expires_at { '2025-12-21 23:33:39' }
    revoked_at { '2025-12-21 23:33:39' }
  end
end
