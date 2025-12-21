FactoryBot.define do
  factory :teacher do
    first_name { "MyString" }
    last_name { "MyString" }
    nickname { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    newsletter_subscribed { false }
    password_digest { "MyString" }
    profile_image_url { "MyString" }
    email_verified_at { "2025-12-20 23:08:30" }
    email_verification_token { "MyString" }
    password_reset_token { "MyString" }
    password_reset_sent_at { "2025-12-20 23:08:30" }
    is_active { false }
  end
end
