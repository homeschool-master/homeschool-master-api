# frozen_string_literal: true

FactoryBot.define do
  factory :teacher do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    is_active { true }
  end
end
