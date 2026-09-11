# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teacher, type: :model do
  describe 'validations' do
    subject { build(:teacher) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:first_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:last_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'associations' do
    it { is_expected.to have_many(:refresh_tokens).dependent(:destroy) }
    it { is_expected.to have_many(:students).dependent(:destroy) }
    it { is_expected.to have_many(:calendar_events).dependent(:destroy) }
  end

  describe 'time_zone' do
    it 'accepts a recognized IANA identifier' do
      expect(FactoryBot.build(:teacher, time_zone: 'America/Denver')).to be_valid
    end

    it 'accepts a zone outside the United States' do
      expect(FactoryBot.build(:teacher, time_zone: 'Europe/Lisbon')).to be_valid
    end

    it 'rejects an unrecognized identifier' do
      expect(FactoryBot.build(:teacher, time_zone: 'Mars/Olympus_Mons')).not_to be_valid
    end

    it 'rejects a Rails style zone name that is not an IANA identifier' do
      expect(FactoryBot.build(:teacher, time_zone: 'Eastern Time (US & Canada)')).not_to be_valid
    end

    it 'reports the zone error' do
      teacher = FactoryBot.build(:teacher, time_zone: 'Nope/Nope')
      teacher.valid?
      expect(teacher.errors[:time_zone]).to include('is not a recognized IANA time zone')
    end

    it 'is valid when the zone is null' do
      expect(FactoryBot.build(:teacher, time_zone: nil)).to be_valid
    end

    it 'is valid when the zone is blank' do
      expect(FactoryBot.build(:teacher, time_zone: '')).to be_valid
    end
  end

  describe '#effective_time_zone' do
    it 'returns the stored zone when one is set' do
      teacher = FactoryBot.build(:teacher, time_zone: 'Europe/Lisbon')
      expect(teacher.effective_time_zone).to eq('Europe/Lisbon')
    end

    it 'falls back when the column is null' do
      teacher = FactoryBot.build(:teacher, time_zone: nil)
      expect(teacher.effective_time_zone).to eq('America/New_York')
    end

    it 'falls back when the column is blank' do
      teacher = FactoryBot.build(:teacher, time_zone: '')
      expect(teacher.effective_time_zone).to eq('America/New_York')
    end

    it 'resolves to a usable zone' do
      teacher = FactoryBot.build(:teacher, time_zone: nil)
      expect(ActiveSupport::TimeZone[teacher.effective_time_zone]).to be_present
    end
  end

  describe 'a teacher created before the column existed' do
    it 'is saved with a null zone and still works' do
      teacher = FactoryBot.create(:teacher)
      expect(teacher.reload.time_zone).to be_nil
      expect(teacher.effective_time_zone).to eq('America/New_York')
    end

    it 'can still be updated without supplying a zone' do
      teacher = FactoryBot.create(:teacher)
      expect(teacher.update(first_name: 'Renamed')).to be(true)
    end
  end
end
