# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventOccurrences do
  let(:teacher) { FactoryBot.create(:teacher) }

  def series(start_time:, end_time:, **rule)
    event = FactoryBot.create(:calendar_event, teacher: teacher,
                                               start_time: start_time, end_time: end_time)
    FactoryBot.create(:recurrence, recurrable: event, **rule)
    event.reload
  end

  def occurrences(event, from, to, zone: 'America/New_York')
    described_class.call(event, from: from, to: to, time_zone: zone)
  end

  describe 'daylight saving' do
    # United States daylight saving in 2026 begins on Sunday 8 March and ends
    # on Sunday 1 November. New York is UTC-5 outside it and UTC-4 inside it.
    #
    # A weekly lesson at 3pm on Thursdays therefore sits at a different UTC
    # instant either side of each change, and every expected value below is
    # written out by hand from that: the point of the spec is to disagree with
    # the code if the code starts doing UTC arithmetic instead.
    #
    #   Thu  5 Mar 2026  3pm EST (UTC-5)  ->  20:00 UTC
    #   Thu 12 Mar 2026  3pm EDT (UTC-4)  ->  19:00 UTC
    #   Thu 19 Mar 2026  3pm EDT (UTC-4)  ->  19:00 UTC
    it 'keeps the local hour across the spring change' do
      event = series(start_time: Time.utc(2026, 3, 5, 20, 0, 0),
                     end_time: Time.utc(2026, 3, 5, 21, 0, 0),
                     frequency: 'weekly', weekdays: [4])

      starts = occurrences(event, Date.new(2026, 3, 1), Date.new(2026, 3, 21)).map(&:start_time)

      expect(starts).to eq([Time.utc(2026, 3, 5, 20, 0, 0),
                            Time.utc(2026, 3, 12, 19, 0, 0),
                            Time.utc(2026, 3, 19, 19, 0, 0)])
    end

    #   Thu 29 Oct 2026  3pm EDT (UTC-4)  ->  19:00 UTC
    #   Thu  5 Nov 2026  3pm EST (UTC-5)  ->  20:00 UTC
    it 'keeps the local hour across the autumn change' do
      event = series(start_time: Time.utc(2026, 10, 29, 19, 0, 0),
                     end_time: Time.utc(2026, 10, 29, 20, 0, 0),
                     frequency: 'weekly', weekdays: [4])

      starts = occurrences(event, Date.new(2026, 10, 25), Date.new(2026, 11, 7)).map(&:start_time)

      expect(starts).to eq([Time.utc(2026, 10, 29, 19, 0, 0),
                            Time.utc(2026, 11, 5, 20, 0, 0)])
    end

    it 'reads 3pm on both sides of the change in the teacher zone' do
      event = series(start_time: Time.utc(2026, 3, 5, 20, 0, 0),
                     end_time: Time.utc(2026, 3, 5, 21, 0, 0),
                     frequency: 'weekly', weekdays: [4])
      zone = ActiveSupport::TimeZone['America/New_York']

      local = occurrences(event, Date.new(2026, 3, 1), Date.new(2026, 3, 21))
              .map { |occurrence| occurrence.start_time.in_time_zone(zone).strftime('%H:%M') }

      expect(local).to eq(%w[15:00 15:00 15:00])
    end

    # Pacific changes on the same dates, so the same series read in a second
    # zone proves the zone is honoured rather than a New York offset hardcoded.
    #   Thu  5 Mar 2026  noon PST (UTC-8)  ->  20:00 UTC
    #   Thu 12 Mar 2026  noon PDT (UTC-7)  ->  19:00 UTC
    it 'honours whichever zone it is given' do
      event = series(start_time: Time.utc(2026, 3, 5, 20, 0, 0),
                     end_time: Time.utc(2026, 3, 5, 21, 0, 0),
                     frequency: 'weekly', weekdays: [4])

      starts = occurrences(event, Date.new(2026, 3, 1), Date.new(2026, 3, 14),
                           zone: 'America/Los_Angeles').map(&:start_time)

      expect(starts).to eq([Time.utc(2026, 3, 5, 20, 0, 0), Time.utc(2026, 3, 12, 19, 0, 0)])
    end

    it 'carries the length of the event rather than its finishing wall clock' do
      event = series(start_time: Time.utc(2026, 3, 5, 20, 0, 0),
                     end_time: Time.utc(2026, 3, 5, 21, 30, 0),
                     frequency: 'weekly', weekdays: [4])

      second = occurrences(event, Date.new(2026, 3, 8), Date.new(2026, 3, 14)).first

      expect(second.start_time).to eq(Time.utc(2026, 3, 12, 19, 0, 0))
      expect(second.end_time).to eq(Time.utc(2026, 3, 12, 20, 30, 0))
    end
  end

  describe 'the anchor date' do
    # 8pm Pacific on the 14th is already the 15th in UTC, so a series read off
    # the UTC date would repeat on the wrong day of the week.
    it 'is the local date, not the UTC one' do
      event = series(start_time: Time.utc(2026, 9, 15, 3, 0, 0),
                     end_time: Time.utc(2026, 9, 15, 4, 0, 0),
                     frequency: 'daily')

      dates = occurrences(event, Date.new(2026, 9, 14), Date.new(2026, 9, 16),
                          zone: 'America/Los_Angeles').map(&:date)

      expect(dates).to eq([Date.new(2026, 9, 14), Date.new(2026, 9, 15), Date.new(2026, 9, 16)])
    end
  end

  describe 'exceptions' do
    it 'leaves out a deleted occurrence' do
      event = series(start_time: Time.utc(2026, 9, 1, 14, 0, 0),
                     end_time: Time.utc(2026, 9, 1, 15, 0, 0),
                     frequency: 'daily')
      event.recurrence.recurrence_exceptions.create!(occurrence_date: Date.new(2026, 9, 2))

      dates = occurrences(event, Date.new(2026, 9, 1), Date.new(2026, 9, 4)).map(&:date)

      expect(dates).to eq([Date.new(2026, 9, 1), Date.new(2026, 9, 3), Date.new(2026, 9, 4)])
    end

    # An edited occurrence is a standalone row the feed returns on its own
    # account, so the rule must not produce it a second time.
    it 'leaves out an occurrence that was replaced' do
      event = series(start_time: Time.utc(2026, 9, 1, 14, 0, 0),
                     end_time: Time.utc(2026, 9, 1, 15, 0, 0),
                     frequency: 'daily')
      replacement = FactoryBot.create(:calendar_event, teacher: teacher)
      event.recurrence.recurrence_exceptions.create!(occurrence_date: Date.new(2026, 9, 2),
                                                     replacement_id: replacement.id)

      dates = occurrences(event, Date.new(2026, 9, 1), Date.new(2026, 9, 3)).map(&:date)

      expect(dates).to eq([Date.new(2026, 9, 1), Date.new(2026, 9, 3)])
    end
  end

  it 'returns nothing for an event that does not repeat' do
    event = FactoryBot.create(:calendar_event, teacher: teacher)

    expect(occurrences(event, Date.new(2026, 9, 1), Date.new(2026, 9, 30))).to eq([])
  end
end
