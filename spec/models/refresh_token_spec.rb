# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshToken, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:teacher) }
  end

  describe 'validations' do
    subject { build(:refresh_token) }

    it { is_expected.to validate_presence_of(:token) }
    it { is_expected.to validate_presence_of(:jti) }
    it { is_expected.to validate_presence_of(:expires_at) }
    it { is_expected.to validate_uniqueness_of(:token) }
    it { is_expected.to validate_uniqueness_of(:jti) }
  end

  describe '#expired?' do
    it 'is false when expiry is in the future' do
      expect(build(:refresh_token).expired?).to be(false)
    end

    it 'is true when expiry is in the past' do
      expect(build(:refresh_token, :expired).expired?).to be(true)
    end
  end

  describe '#revoked?' do
    it 'is false when revoked_at is nil' do
      expect(build(:refresh_token).revoked?).to be(false)
    end

    it 'is true when revoked_at is set' do
      expect(build(:refresh_token, :revoked).revoked?).to be(true)
    end
  end

  describe '#valid_token?' do
    it 'is true for an active token' do
      expect(build(:refresh_token).valid_token?).to be(true)
    end

    it 'is false when expired' do
      expect(build(:refresh_token, :expired).valid_token?).to be(false)
    end

    it 'is false when revoked' do
      expect(build(:refresh_token, :revoked).valid_token?).to be(false)
    end
  end

  describe '#revoke!' do
    it 'sets revoked_at' do
      token = create(:refresh_token)
      token.revoke!
      expect(token.reload.revoked_at).to be_present
    end

    it 'makes the token invalid' do
      token = create(:refresh_token)
      token.revoke!
      expect(token.valid_token?).to be(false)
    end
  end

  describe '.active' do
    it 'includes non-revoked, unexpired tokens' do
      token = create(:refresh_token)
      expect(described_class.active).to include(token)
    end

    it 'excludes revoked tokens' do
      token = create(:refresh_token, :revoked)
      expect(described_class.active).not_to include(token)
    end

    it 'excludes expired tokens' do
      token = create(:refresh_token, :expired)
      expect(described_class.active).not_to include(token)
    end
  end

  describe '.find_valid_by_token' do
    it 'finds an active token by its token string' do
      token = create(:refresh_token)
      expect(described_class.find_valid_by_token(token.token)).to eq(token)
    end

    it 'does not find a revoked token' do
      token = create(:refresh_token, :revoked)
      expect(described_class.find_valid_by_token(token.token)).to be_nil
    end

    it 'does not find an expired token' do
      token = create(:refresh_token, :expired)
      expect(described_class.find_valid_by_token(token.token)).to be_nil
    end
  end

  describe '.revoke_all_for_teacher' do
    it 'revokes every token for the given teacher' do
      teacher = create(:teacher)
      create(:refresh_token, teacher: teacher)
      create(:refresh_token, teacher: teacher)
      described_class.revoke_all_for_teacher(teacher.id)
      expect(described_class.active.where(teacher_id: teacher.id)).to be_empty
    end

    it 'leaves other teachers tokens untouched' do
      teacher = create(:teacher)
      other = create(:teacher, email: 'other@example.com')
      other_token = create(:refresh_token, teacher: other)
      create(:refresh_token, teacher: teacher)
      described_class.revoke_all_for_teacher(teacher.id)
      expect(described_class.active).to include(other_token)
    end
  end

  describe 'dependent destroy' do
    it 'is removed when its teacher is destroyed' do
      teacher = create(:teacher)
      create(:refresh_token, teacher: teacher)
      expect { teacher.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
