# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecurrenceSchedule do
  # Expected dates are written out by hand throughout: a schedule spec that
  # computes its own expectations only proves the code agrees with itself.
  def schedule(recurrence, start_date)
    described_class.new(recurrence, start_date: start_date)
  end

  def build_rule(*traits, **attributes)
    FactoryBot.build(:recurrence, *traits, **attributes)
  end

  describe 'daily' do
    it 'returns every day in the window from the start' do
      rule = build_rule(:daily)

      dates = schedule(rule, Date.new(2026, 9, 14)).dates_between(Date.new(2026, 9, 12),
                                                                  Date.new(2026, 9, 17))

      expect(dates).to eq([Date.new(2026, 9, 14), Date.new(2026, 9, 15),
                           Date.new(2026, 9, 16), Date.new(2026, 9, 17)])
    end
  end

  describe 'weekly' do
    # September 2026: the 1st is a Tuesday, so Tuesdays are 1, 8, 15, 22, 29
    # and Thursdays are 3, 10, 17, 24.
    it 'returns every named day of the week, several at once' do
      rule = build_rule(frequency: 'weekly', weekdays: [2, 4])

      dates = schedule(rule, Date.new(2026, 9, 1)).dates_between(Date.new(2026, 9, 1),
                                                                 Date.new(2026, 9, 14))

      expect(dates).to eq([Date.new(2026, 9, 1), Date.new(2026, 9, 3), Date.new(2026, 9, 8),
                           Date.new(2026, 9, 10)])
    end

    it 'is one series rather than two, in date order' do
      rule = build_rule(frequency: 'weekly', weekdays: [2, 4])

      dates = schedule(rule, Date.new(2026, 9, 1)).dates_between(Date.new(2026, 9, 1),
                                                                 Date.new(2026, 9, 30))

      expect(dates.map(&:day)).to eq([1, 3, 8, 10, 15, 17, 22, 24, 29])
    end

    it 'falls back to the day it started on when no days are named' do
      rule = build_rule(frequency: 'weekly', weekdays: [])

      dates = schedule(rule, Date.new(2026, 9, 2)).dates_between(Date.new(2026, 9, 1),
                                                                 Date.new(2026, 9, 21))

      expect(dates).to eq([Date.new(2026, 9, 2), Date.new(2026, 9, 9), Date.new(2026, 9, 16)])
    end

    it 'never returns a date before the series starts' do
      rule = build_rule(frequency: 'weekly', weekdays: [2])

      dates = schedule(rule, Date.new(2026, 9, 15)).dates_between(Date.new(2026, 9, 1),
                                                                  Date.new(2026, 9, 30))

      expect(dates).to eq([Date.new(2026, 9, 15), Date.new(2026, 9, 22), Date.new(2026, 9, 29)])
    end
  end

  describe 'monthly on the same date' do
    it 'returns that date each month' do
      rule = build_rule(:monthly_by_date)

      dates = schedule(rule, Date.new(2026, 9, 12)).dates_between(Date.new(2026, 9, 1),
                                                                  Date.new(2026, 12, 31))

      expect(dates).to eq([Date.new(2026, 9, 12), Date.new(2026, 10, 12),
                           Date.new(2026, 11, 12), Date.new(2026, 12, 12)])
    end

    # Clamping back to the 30th would move the occurrence onto a day the
    # teacher did not pick, so the month is skipped instead.
    it 'skips a month that has no such date' do
      rule = build_rule(:monthly_by_date)

      dates = schedule(rule, Date.new(2026, 8, 31)).dates_between(Date.new(2026, 8, 1),
                                                                  Date.new(2026, 11, 30))

      expect(dates).to eq([Date.new(2026, 8, 31), Date.new(2026, 10, 31)])
    end
  end

  describe 'monthly on the same weekday position' do
    # 11 September 2026 is the second Friday. The second Friday of October is
    # the 9th, of November the 13th, of December the 11th.
    it 'returns the same position each month' do
      rule = build_rule(:monthly_by_position)

      dates = schedule(rule, Date.new(2026, 9, 11)).dates_between(Date.new(2026, 9, 1),
                                                                  Date.new(2026, 12, 31))

      expect(dates).to eq([Date.new(2026, 9, 11), Date.new(2026, 10, 9),
                           Date.new(2026, 11, 13), Date.new(2026, 12, 11)])
    end

    # 31 July 2026 is the fifth Friday. August 2026 has Fridays on the 7th,
    # 14th, 21st and 28th and no fifth, so August produces nothing. October
    # has Fridays on the 2nd, 9th, 16th, 23rd and 30th, so its fifth is the
    # 30th.
    it 'skips a month with no fifth Friday rather than moving it to the fourth' do
      rule = build_rule(:monthly_by_position)

      dates = schedule(rule, Date.new(2026, 7, 31)).dates_between(Date.new(2026, 7, 1),
                                                                  Date.new(2026, 12, 31))

      expect(dates).to eq([Date.new(2026, 7, 31), Date.new(2026, 10, 30)])
    end

    it 'counts the first week correctly when the month opens on that weekday' do
      # 1 May 2026 is a Friday, so it is the first Friday.
      rule = build_rule(:monthly_by_position)

      dates = schedule(rule, Date.new(2026, 5, 1)).dates_between(Date.new(2026, 5, 1),
                                                                 Date.new(2026, 7, 31))

      expect(dates).to eq([Date.new(2026, 5, 1), Date.new(2026, 6, 5), Date.new(2026, 7, 3)])
    end
  end

  describe 'yearly' do
    it 'returns the same date each year' do
      rule = build_rule(:yearly)

      dates = schedule(rule, Date.new(2026, 9, 12)).dates_between(Date.new(2026, 1, 1),
                                                                  Date.new(2029, 12, 31))

      expect(dates).to eq([Date.new(2026, 9, 12), Date.new(2027, 9, 12),
                           Date.new(2028, 9, 12), Date.new(2029, 9, 12)])
    end

    it 'skips a year with no 29 February' do
      rule = build_rule(:yearly)

      dates = schedule(rule, Date.new(2028, 2, 29)).dates_between(Date.new(2028, 1, 1),
                                                                  Date.new(2033, 12, 31))

      expect(dates).to eq([Date.new(2028, 2, 29), Date.new(2032, 2, 29)])
    end
  end

  describe 'the end of a series' do
    it 'never returns a date after until_date' do
      rule = build_rule(frequency: 'weekly', weekdays: [2], until_date: Date.new(2026, 9, 16))

      dates = schedule(rule, Date.new(2026, 9, 1)).dates_between(Date.new(2026, 9, 1),
                                                                 Date.new(2026, 9, 30))

      expect(dates).to eq([Date.new(2026, 9, 1), Date.new(2026, 9, 8), Date.new(2026, 9, 15)])
    end

    it 'returns nothing once the window is entirely past the end' do
      rule = build_rule(frequency: 'weekly', weekdays: [2], until_date: Date.new(2026, 9, 16))

      dates = schedule(rule, Date.new(2026, 9, 1)).dates_between(Date.new(2026, 10, 1),
                                                                 Date.new(2026, 10, 31))

      expect(dates).to eq([])
    end

    it 'runs on with no end date' do
      rule = build_rule(frequency: 'weekly', weekdays: [2], until_date: nil)

      dates = schedule(rule, Date.new(2026, 9, 1)).dates_between(Date.new(2030, 9, 1),
                                                                 Date.new(2030, 9, 30))

      expect(dates.length).to eq(4)
    end
  end
end
