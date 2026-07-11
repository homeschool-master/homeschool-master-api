# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeacherSerializer do
  let(:teacher) { FactoryBot.create(:teacher) }

  describe '.render' do
    subject(:payload) { described_class.render(teacher) }

    it 'returns the public attributes' do
      expect(payload).to eq(
        id: teacher.id,
        first_name: teacher.first_name,
        middle_name: teacher.middle_name,
        last_name: teacher.last_name,
        email: teacher.email,
        notify_account_updates: teacher.notify_account_updates,
        notify_product_updates: teacher.notify_product_updates,
        notify_homeschool_resources: teacher.notify_homeschool_resources,
        onboarding_completed: teacher.onboarding_completed,
        created_at: teacher.created_at
      )
    end

    it 'does not expose the password digest' do
      expect(payload).not_to have_key(:password_digest)
    end

    it 'does not expose reset or verification tokens' do
      expect(payload).not_to have_key(:password_reset_token)
      expect(payload).not_to have_key(:email_verification_token)
    end
  end
end
