# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskSeriesEdit do
  let(:teacher) { FactoryBot.create(:teacher) }

  # Weekly on Fridays from 4 September 2026: 4, 11, 18, 25 September.
  let(:task) do
    record = FactoryBot.create(:task, teacher: teacher, title: 'Submit reimbursement',
                                      due_date: Date.new(2026, 9, 4))
    record.create_recurrence!(frequency: 'weekly', weekdays: [5])
    record.reload
  end

  def dates_for(record, from: Date.new(2026, 9, 1), to: Date.new(2026, 10, 31))
    TaskOccurrences.call(record.reload, from: from, to: to).map(&:date)
  end

  describe 'this occurrence' do
    it 'detaches it into a standalone task on its own date' do
      editor = described_class.new(task, occurrence_date: Date.new(2026, 9, 18))
      replacement = editor.detach({ 'title' => 'Submit reimbursement with receipts' }, nil)

      expect(replacement).to be_persisted
      expect(replacement.due_date).to eq(Date.new(2026, 9, 18))
      expect(replacement.recurrence).to be_nil
    end

    it 'leaves every other occurrence on the series alone' do
      described_class.new(task, occurrence_date: Date.new(2026, 9, 18)).detach({ 'title' => 'Changed' }, nil)
      expect(dates_for(task)).to eq([4, 11, 25].map { |day| Date.new(2026, 9, day) } +
                                    [2, 9, 16, 23, 30].map { |day| Date.new(2026, 10, day) })
    end

    it 'carries a tick already on that occurrence onto the detached task' do
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 18),
                                    completed_at: Time.utc(2026, 9, 18, 8, 0, 0))
      replacement = described_class.new(task, occurrence_date: Date.new(2026, 9, 18))
                                   .detach({ 'title' => 'Changed' }, nil)

      expect(replacement.completed).to be(true)
      expect(task.task_completions.reload).to be_empty
    end

    it 'keeps the students the series named' do
      student = FactoryBot.create(:student, teacher: teacher)
      task.students = [student]
      replacement = described_class.new(task, occurrence_date: Date.new(2026, 9, 18))
                                   .detach({ 'title' => 'Changed' }, nil)
      expect(replacement.student_ids).to eq([student.id])
    end
  end

  describe 'this and future' do
    it 'ends the original the day before and starts a second series' do
      successor = described_class.new(task, occurrence_date: Date.new(2026, 9, 18))
                                 .split({ 'title' => 'Submit reimbursement online' }, nil)

      expect(task.reload.recurrence.until_date).to eq(Date.new(2026, 9, 17))
      expect(successor.recurrence.frequency).to eq('weekly')
      expect(dates_for(task)).to eq([Date.new(2026, 9, 4), Date.new(2026, 9, 11)])
    end

    it 'gives the rest of the dates to the successor' do
      successor = described_class.new(task, occurrence_date: Date.new(2026, 9, 18))
                                 .split({ 'title' => 'Changed' }, nil)
      expect(dates_for(successor)).to eq([18, 25].map { |day| Date.new(2026, 9, day) } +
                                         [2, 9, 16, 23, 30].map { |day| Date.new(2026, 10, day) })
    end

    it 'moves ticks after the split onto the successor and leaves earlier ones' do
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 11), completed_at: Time.current)
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 25), completed_at: Time.current)
      successor = described_class.new(task, occurrence_date: Date.new(2026, 9, 18))
                                 .split({ 'title' => 'Changed' }, nil)

      expect(task.reload.task_completions.pluck(:occurrence_date)).to eq([Date.new(2026, 9, 11)])
      expect(successor.task_completions.pluck(:occurrence_date)).to eq([Date.new(2026, 9, 25)])
    end

    it 'is the same request as all when it starts at the first occurrence' do
      expect(described_class.new(task, occurrence_date: Date.new(2026, 9, 4))).to be_first_occurrence
    end
  end

  describe 'all of it' do
    it 'removes the series and the occurrences edited out of it' do
      described_class.new(task, occurrence_date: Date.new(2026, 9, 11)).detach({ 'title' => 'Changed' }, nil)
      expect { described_class.new(task, occurrence_date: nil).destroy_series }
        .to change(Task, :count).by(-2)
    end

    it 'takes its ticks with it' do
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 11), completed_at: Time.current)
      expect { described_class.new(task, occurrence_date: nil).destroy_series }
        .to change(TaskCompletion, :count).by(-1)
    end
  end

  describe 'skipping and truncating' do
    it 'skip takes one occurrence out and leaves the rest' do
      described_class.new(task, occurrence_date: Date.new(2026, 9, 11)).skip
      expect(dates_for(task, to: Date.new(2026, 9, 30)))
        .to eq([4, 18, 25].map { |day| Date.new(2026, 9, day) })
    end

    it 'truncate drops this occurrence and everything after it' do
      described_class.new(task, occurrence_date: Date.new(2026, 9, 18)).truncate
      expect(dates_for(task)).to eq([Date.new(2026, 9, 4), Date.new(2026, 9, 11)])
    end

    it 'truncate drops the ticks that no longer have an occurrence' do
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 11), completed_at: Time.current)
      task.task_completions.create!(occurrence_date: Date.new(2026, 9, 25), completed_at: Time.current)
      described_class.new(task, occurrence_date: Date.new(2026, 9, 18)).truncate
      expect(task.task_completions.reload.pluck(:occurrence_date)).to eq([Date.new(2026, 9, 11)])
    end
  end
end
