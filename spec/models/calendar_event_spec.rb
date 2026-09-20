# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CalendarEvent, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:teacher) }
    it { is_expected.to have_many(:event_attendees).dependent(:destroy) }
    it { is_expected.to have_many(:students).through(:event_attendees) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_presence_of(:start_time) }
    it { is_expected.to validate_presence_of(:end_time) }

    it 'is valid with an end time after the start time' do
      event = FactoryBot.build(:calendar_event)
      expect(event).to be_valid
    end

    it 'is not valid when the end time is before the start time' do
      event = FactoryBot.build(:calendar_event, end_time: Time.utc(2026, 9, 15, 13, 0, 0))
      expect(event).not_to be_valid
    end

    it 'reports the end time error' do
      event = FactoryBot.build(:calendar_event, end_time: Time.utc(2026, 9, 15, 13, 0, 0))
      event.valid?
      expect(event.errors[:end_time]).to include('must be after the start time')
    end

    it 'is not valid when the end time equals the start time' do
      event = FactoryBot.build(:calendar_event, end_time: Time.utc(2026, 9, 15, 14, 0, 0))
      expect(event).not_to be_valid
    end

    it 'is valid without notes or a location' do
      event = FactoryBot.build(:calendar_event, notes: nil, location: nil)
      expect(event).to be_valid
    end

    it 'is not valid without a teacher' do
      event = FactoryBot.build(:calendar_event, teacher: nil)
      expect(event).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'is not an all day event by default' do
      event = described_class.new
      expect(event.all_day).to be(false)
    end
  end

  describe 'attendees' do
    it 'exposes its students through the join table' do
      teacher = FactoryBot.create(:teacher)
      event = FactoryBot.create(:calendar_event, teacher: teacher)
      student = FactoryBot.create(:student, teacher: teacher)
      FactoryBot.create(:event_attendee, calendar_event: event, student: student)
      expect(event.students).to eq([student])
    end

    it 'destroys its attendee rows when destroyed' do
      teacher = FactoryBot.create(:teacher)
      event = FactoryBot.create(:calendar_event, teacher: teacher)
      FactoryBot.create(:event_attendee, calendar_event: event,
                                         student: FactoryBot.create(:student, teacher: teacher))
      expect { event.destroy }.to change(EventAttendee, :count).by(-1)
    end
  end

  describe 'created_time_zone' do
    let(:teacher) { FactoryBot.create(:teacher, time_zone: 'Europe/Lisbon') }

    it 'keeps a client supplied zone' do
      event = FactoryBot.create(:calendar_event, teacher: teacher, created_time_zone: 'America/Denver')
      expect(event.created_time_zone).to eq('America/Denver')
    end

    it "falls back to the teacher's zone when the client sends none" do
      event = FactoryBot.create(:calendar_event, teacher: teacher, created_time_zone: nil)
      expect(event.created_time_zone).to eq('Europe/Lisbon')
    end

    it "falls back to the teacher's zone when the client sends a blank value" do
      event = FactoryBot.create(:calendar_event, teacher: teacher, created_time_zone: '')
      expect(event.created_time_zone).to eq('Europe/Lisbon')
    end

    it "falls back to the teacher's default when the teacher has no zone" do
      event = FactoryBot.create(:calendar_event, teacher: FactoryBot.create(:teacher), created_time_zone: nil)
      expect(event.created_time_zone).to eq('America/New_York')
    end

    it 'rejects an unrecognized identifier rather than falling back' do
      event = FactoryBot.build(:calendar_event, teacher: teacher, created_time_zone: 'Mars/Olympus_Mons')
      expect(event).not_to be_valid
    end

    it 'reports the zone error' do
      event = FactoryBot.build(:calendar_event, teacher: teacher, created_time_zone: 'Nope/Nope')
      event.valid?
      expect(event.errors[:created_time_zone]).to include('is not a recognized IANA time zone')
    end

    it 'is not repopulated on update' do
      event = FactoryBot.create(:calendar_event, teacher: teacher, created_time_zone: 'America/Denver')
      teacher.update!(time_zone: 'Asia/Tokyo')
      event.update!(title: 'Renamed')
      expect(event.reload.created_time_zone).to eq('America/Denver')
    end

    it 'does not shift the stored timestamps' do
      event = FactoryBot.create(:calendar_event, teacher: teacher, created_time_zone: 'Asia/Tokyo')
      expect(event.reload.start_time).to eq(Time.utc(2026, 9, 15, 14, 0, 0))
    end
  end

  describe '.in_range' do
    let(:teacher) { FactoryBot.create(:teacher) }
    let(:range_start) { Time.utc(2026, 9, 14, 0, 0, 0) }
    let(:range_end) { Time.utc(2026, 9, 20, 23, 59, 59) }

    it 'includes an event inside the range' do
      event = FactoryBot.create(:calendar_event, teacher: teacher)
      expect(described_class.in_range(range_start, range_end)).to include(event)
    end

    it 'excludes an event entirely before the range' do
      event = FactoryBot.create(:calendar_event, teacher: teacher,
                                                 start_time: Time.utc(2026, 9, 1, 9, 0, 0),
                                                 end_time: Time.utc(2026, 9, 1, 10, 0, 0))
      expect(described_class.in_range(range_start, range_end)).not_to include(event)
    end

    it 'excludes an event entirely after the range' do
      event = FactoryBot.create(:calendar_event, teacher: teacher,
                                                 start_time: Time.utc(2026, 10, 1, 9, 0, 0),
                                                 end_time: Time.utc(2026, 10, 1, 10, 0, 0))
      expect(described_class.in_range(range_start, range_end)).not_to include(event)
    end

    it 'includes an event that straddles the start of the range' do
      event = FactoryBot.create(:calendar_event, teacher: teacher,
                                                 start_time: Time.utc(2026, 9, 13, 9, 0, 0),
                                                 end_time: Time.utc(2026, 9, 15, 10, 0, 0))
      expect(described_class.in_range(range_start, range_end)).to include(event)
    end

    it 'includes an event that straddles the end of the range' do
      event = FactoryBot.create(:calendar_event, teacher: teacher,
                                                 start_time: Time.utc(2026, 9, 19, 9, 0, 0),
                                                 end_time: Time.utc(2026, 9, 25, 10, 0, 0))
      expect(described_class.in_range(range_start, range_end)).to include(event)
    end
  end

  describe '.for_students' do
    it 'returns only events the student attends' do
      teacher = FactoryBot.create(:teacher)
      student = FactoryBot.create(:student, teacher: teacher)
      attended = FactoryBot.create(:calendar_event, teacher: teacher)
      unattended = FactoryBot.create(:calendar_event, teacher: teacher)
      FactoryBot.create(:event_attendee, calendar_event: attended, student: student)
      results = described_class.for_students([student.id])
      expect(results).to eq([attended])
      expect(results).not_to include(unattended)
    end

    it 'returns events any of the students attend rather than only shared ones' do
      teacher = FactoryBot.create(:teacher)
      first = FactoryBot.create(:student, teacher: teacher)
      second = FactoryBot.create(:student, teacher: teacher)
      third = FactoryBot.create(:student, teacher: teacher)
      firsts = FactoryBot.create(:calendar_event, teacher: teacher)
      seconds = FactoryBot.create(:calendar_event, teacher: teacher)
      thirds = FactoryBot.create(:calendar_event, teacher: teacher)
      FactoryBot.create(:event_attendee, calendar_event: firsts, student: first)
      FactoryBot.create(:event_attendee, calendar_event: seconds, student: second)
      FactoryBot.create(:event_attendee, calendar_event: thirds, student: third)

      results = described_class.for_students([first.id, second.id])

      expect(results).to contain_exactly(firsts, seconds)
    end

    it 'returns an event both selected students attend exactly once' do
      teacher = FactoryBot.create(:teacher)
      first = FactoryBot.create(:student, teacher: teacher)
      second = FactoryBot.create(:student, teacher: teacher)
      shared = FactoryBot.create(:calendar_event, teacher: teacher)
      FactoryBot.create(:event_attendee, calendar_event: shared, student: first)
      FactoryBot.create(:event_attendee, calendar_event: shared, student: second)

      expect(described_class.for_students([first.id, second.id])).to eq([shared])
    end
  end

  describe '.chronological' do
    it 'orders events by start time ascending' do
      teacher = FactoryBot.create(:teacher)
      later = FactoryBot.create(:calendar_event, teacher: teacher,
                                                 start_time: Time.utc(2026, 9, 16, 9, 0, 0),
                                                 end_time: Time.utc(2026, 9, 16, 10, 0, 0))
      earlier = FactoryBot.create(:calendar_event, teacher: teacher,
                                                   start_time: Time.utc(2026, 9, 15, 9, 0, 0),
                                                   end_time: Time.utc(2026, 9, 15, 10, 0, 0))
      expect(described_class.chronological.to_a).to eq([earlier, later])
    end
  end
end
