# frozen_string_literal: true

require 'rails_helper'

# Every expected date below is worked out by hand in the comment above it.
RSpec.describe TaskOccurrences do
  let(:teacher) { FactoryBot.create(:teacher) }

  def repeating(due:, **rule)
    task = FactoryBot.create(:task, teacher: teacher, due_date: due)
    task.create_recurrence!({ frequency: 'weekly', weekdays: [due.wday] }.merge(rule))
    task.reload
  end

  describe 'expansion' do
    # Anchored Friday 4 September, weekly on Fridays: 4, 11, 18, 25 September.
    it 'returns the due dates the rule produces' do
      task = repeating(due: Date.new(2026, 9, 4))
      dates = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 30))
      expect(dates.map(&:date)).to eq([4, 11, 18, 25].map { |day| Date.new(2026, 9, day) })
    end

    it 'produces dates and nothing else, with no times anywhere on them' do
      task = repeating(due: Date.new(2026, 9, 4))
      occurrence = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 10)).first
      expect(occurrence.date).to be_a(Date)
      expect(occurrence.members).to contain_exactly(:date, :completed_at)
    end

    it 'never reaches before the task is due' do
      task = repeating(due: Date.new(2026, 9, 18))
      dates = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 30))
      expect(dates.map(&:date)).to eq([Date.new(2026, 9, 18), Date.new(2026, 9, 25)])
    end

    it 'returns nothing for a task that does not repeat' do
      task = FactoryBot.create(:task, teacher: teacher)
      expect(described_class.call(task, from: Date.new(2026, 1, 1), to: Date.new(2026, 12, 31))).to be_empty
    end

    it 'returns nothing for a repeating task with no due date to repeat from' do
      task = repeating(due: Date.new(2026, 9, 4))
      task.update_column(:due_date, nil)
      expect(described_class.call(task.reload, from: Date.new(2026, 9, 1),
                                               to: Date.new(2026, 9, 30))).to be_empty
    end

    it 'leaves out an occurrence that was taken out of the series' do
      task = repeating(due: Date.new(2026, 9, 4))
      task.recurrence.recurrence_exceptions.create!(occurrence_date: Date.new(2026, 9, 11))
      dates = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 30))
      expect(dates.map(&:date)).to eq([4, 18, 25].map { |day| Date.new(2026, 9, day) })
    end
  end

  describe 'a monthly task on a weekday position' do
    # 4 September 2026 is the first Friday. First Fridays after it: 2 October,
    # 6 November, 4 December, 1 January.
    let(:task) do
      repeating(due: Date.new(2026, 9, 4), frequency: 'monthly', weekdays: [],
                monthly_anchor: 'weekday_position')
    end

    it 'lands on the same position each month' do
      dates = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2027, 1, 31))
      expect(dates.map(&:date)).to eq([
                                        Date.new(2026, 9, 4), Date.new(2026, 10, 2), Date.new(2026, 11, 6),
                                        Date.new(2026, 12, 4), Date.new(2027, 1, 1)
                                      ])
    end

    # 31 July 2026 is the fifth Friday. Months with a fifth Friday after it:
    # October 2026 (2, 9, 16, 23, 30) and January 2027 (1, 8, 15, 22, 29).
    # August, September, November and December have only four, so they are
    # skipped rather than falling back to the fourth.
    it 'skips the months with no such position rather than moving the task' do
      fifth_friday = repeating(due: Date.new(2026, 7, 31), frequency: 'monthly', weekdays: [],
                               monthly_anchor: 'weekday_position')
      dates = described_class.call(fifth_friday, from: Date.new(2026, 8, 1), to: Date.new(2027, 1, 31))
      expect(dates.map(&:date)).to eq([Date.new(2026, 10, 30), Date.new(2027, 1, 29)])
    end
  end

  describe 'ticks' do
    let(:task) { repeating(due: Date.new(2026, 9, 4)) }

    it 'carries the tick recorded against one occurrence' do
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 11),
                                    completed_at: Time.utc(2026, 9, 11, 9, 0, 0))
      dates = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 30))
      expect(dates.map { |occurrence| [occurrence.date.day, occurrence.completed] })
        .to eq([[4, false], [11, true], [18, false], [25, false]])
    end

    it 'leaves every other occurrence untouched' do
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 11), completed_at: Time.current)
      dates = described_class.call(task, from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 30))
      expect(dates.reject(&:completed).map { |occurrence| occurrence.date.day }).to eq([4, 18, 25])
    end
  end
end
