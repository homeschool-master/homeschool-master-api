# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportCardSnapshot do
  let(:teacher) { FactoryBot.create(:teacher) }
  let(:student) { FactoryBot.create(:student, teacher: teacher) }
  let(:math) { FactoryBot.create(:subject, teacher: teacher, name: 'Math') }
  let(:card) do
    FactoryBot.create(:report_card, teacher: teacher, student: student,
                                    period_start: Date.new(2026, 9, 1), period_end: Date.new(2026, 9, 30))
  end

  def work(title:, earned:, possible: 100, weight: 1, due: Date.new(2026, 9, 10))
    assignment = FactoryBot.create(:assignment, teacher: teacher, subject: math, title: title,
                                                points_possible: possible, weight: weight, due_date: due)
    FactoryBot.create(:assignment_grade, assignment: assignment, student: student, points_earned: earned)
    assignment
  end

  def view
    ReportCardView.call(card.reload)
  end

  describe 'issuing' do
    it 'freezes the subject figures onto the card' do
      work(title: 'Chapter 4', earned: 90)
      described_class.call(card)

      entry = card.report_card_entries.first
      expect(entry.subject_name).to eq('Math')
      expect(entry.percentage).to eq(90)
      expect(entry.letter).to eq('A')
    end

    it 'freezes the overall roll up onto the card' do
      work(title: 'Chapter 4', earned: 90)
      described_class.call(card)

      expect(card.reload.overall_percentage).to eq(90)
      expect(card.overall_letter).to eq('A')
    end

    it 'captures the work each figure was summed from, not only the figure' do
      work(title: 'Chapter 4', earned: 18, possible: 20)
      described_class.call(card)

      captured = card.report_card_entries.first.captured_assignments
      expect(captured.length).to eq(1)
      expect(captured.first['title']).to eq('Chapter 4')
      expect(captured.first['points_earned'].to_f).to eq(18.0)
      expect(captured.first['points_possible'].to_f).to eq(20.0)
      expect(captured.first['percentage'].to_f).to eq(90.0)
    end

    it 'marks the card issued and captured at the same moment' do
      described_class.call(card)
      expect(card.reload.issued_at).to be_present
      expect(card.captured_at).to eq(card.issued_at)
    end
  end

  # The reason the table exists.
  describe 'immutability after issuing' do
    it 'does not change when an assignment it covers is rescored' do
      assignment = work(title: 'Chapter 4', earned: 90)
      described_class.call(card)
      before = view

      assignment.assignment_grades.first.update!(points_earned: 20)

      expect(view).to eq(before)
      expect(view[:overall][:percentage]).to eq(90)
      expect(view[:subjects].first[:percentage]).to eq(90)
    end

    it 'does not change when an assignment it covers is deleted' do
      assignment = work(title: 'Chapter 4', earned: 90)
      described_class.call(card)

      assignment.destroy

      expect(view[:subjects].first[:percentage]).to eq(90)
      expect(view[:subjects].first[:assignments].first['title']).to eq('Chapter 4')
    end

    it 'does not change when new work is added inside its period' do
      work(title: 'Chapter 4', earned: 90)
      described_class.call(card)

      work(title: 'Added later', earned: 10)

      expect(view[:subjects].first[:assignments].length).to eq(1)
      expect(view[:overall][:percentage]).to eq(90)
    end

    it 'keeps the subject name it was issued with when the subject is renamed' do
      work(title: 'Chapter 4', earned: 90)
      described_class.call(card)

      math.update!(name: 'Mathematics')

      expect(view[:subjects].first[:subject_name]).to eq('Math')
    end

    it 'keeps its line when the subject is removed altogether' do
      work(title: 'Chapter 4', earned: 90)
      described_class.call(card)

      math.destroy

      expect(view[:subjects].first[:subject_name]).to eq('Math')
      expect(view[:subjects].first[:percentage]).to eq(90)
    end

    it 'refuses to be edited' do
      described_class.call(card)
      card.reload.title = 'Renamed'

      expect(card.save).to be(false)
      expect(card.errors.full_messages.join).to match(/cannot be changed/)
    end

    it 'refuses to have an entry edited' do
      work(title: 'Chapter 4', earned: 90)
      described_class.call(card)
      entry = card.reload.report_card_entries.first
      entry.comments = 'Sneaking a change in'

      expect(entry.save).to be(false)
    end
  end

  # A draft is the opposite: it tracks current grades until it is issued.
  describe 'a draft before it is issued' do
    it 'computes from current grades rather than from anything stored' do
      work(title: 'Chapter 4', earned: 90)
      expect(view[:subjects].first[:percentage]).to eq(90)
    end

    it 'follows a rescore, so a card started on Monday is right on Tuesday' do
      assignment = work(title: 'Chapter 4', earned: 90)
      expect(view[:overall][:percentage]).to eq(90)

      assignment.assignment_grades.first.update!(points_earned: 50)

      expect(view[:overall][:percentage]).to eq(50)
    end

    it 'picks up work added after it was created' do
      work(title: 'Chapter 4', earned: 90)
      expect(view[:subjects].first[:assignments].length).to eq(1)

      work(title: 'Added later', earned: 80)

      expect(view[:subjects].first[:assignments].length).to eq(2)
    end
  end
end
