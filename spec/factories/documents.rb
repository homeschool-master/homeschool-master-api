# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    association :teacher
    sequence(:title) { |n| "Receipt #{n}" }

    # Attached by default: a document without bytes is not a document, and the
    # model refuses one.
    after(:build) do |document|
      unless document.file.attached?
        document.file.attach(
          io: Rails.root.join('spec/fixtures/files/receipt.png').open,
          filename: 'receipt.png', content_type: 'image/png'
        )
      end
    end
  end
end
