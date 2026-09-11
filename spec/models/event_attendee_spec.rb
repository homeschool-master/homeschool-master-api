# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventAttendee, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:calendar_event) }
    it { is_expected.to belong_to(:student) }
  end

  describe 'validations' do
    let(:teacher) { FactoryBot.create(:teacher) }
    let(:event) { FactoryBot.create(:calendar_event, teacher: teacher) }
    let(:student) { FactoryBot.create(:student, teacher: teacher) }

    it 'is valid for a new pair' do
      attendee = described_class.new(calendar_event: event, student: student)
      expect(attendee).to be_valid
    end

    it 'is not valid when the pair already exists' do
      described_class.create!(calendar_event: event, student: student)
      duplicate = described_class.new(calendar_event: event, student: student)
      expect(duplicate).not_to be_valid
    end

    it 'reports the duplicate pair error' do
      described_class.create!(calendar_event: event, student: student)
      duplicate = described_class.new(calendar_event: event, student: student)
      duplicate.valid?
      expect(duplicate.errors[:student_id]).to include('is already an attendee of this event')
    end

    it 'allows the same student on a different event' do
      described_class.create!(calendar_event: event, student: student)
      other_event = FactoryBot.create(:calendar_event, teacher: teacher)
      expect(described_class.new(calendar_event: other_event, student: student)).to be_valid
    end

    it 'allows a different student on the same event' do
      described_class.create!(calendar_event: event, student: student)
      other_student = FactoryBot.create(:student, teacher: teacher)
      expect(described_class.new(calendar_event: event, student: other_student)).to be_valid
    end
  end
end
