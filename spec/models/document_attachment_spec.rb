# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentAttachment, type: :model do
  let(:teacher) { FactoryBot.create(:teacher) }
  let(:document) { FactoryBot.create(:document, teacher: teacher) }

  describe 'what a document can be filed against' do
    it 'takes an assignment, a task and a calendar event' do
      subject_record = FactoryBot.create(:subject, teacher: teacher)
      targets = [
        FactoryBot.create(:assignment, teacher: teacher, subject: subject_record),
        FactoryBot.create(:task, teacher: teacher),
        FactoryBot.create(:calendar_event, teacher: teacher)
      ]

      targets.each { |target| document.document_attachments.create!(attachable: target) }

      expect(document.document_attachments.count).to eq(3)
    end

    it 'refuses a record belonging to another teacher' do
      theirs = FactoryBot.create(:task, teacher: FactoryBot.create(:teacher))
      attachment = document.document_attachments.build(attachable: theirs)

      expect(attachment).not_to be_valid
    end

    it 'refuses the same filing twice' do
      task = FactoryBot.create(:task, teacher: teacher)
      document.document_attachments.create!(attachable: task)

      expect(document.document_attachments.build(attachable: task)).not_to be_valid
    end
  end

  describe 'occurrences' do
    let(:event) do
      FactoryBot.create(:calendar_event, teacher: teacher).tap do |record|
        record.create_recurrence!(frequency: 'weekly', weekdays: [2])
      end
    end

    it 'tells one occurrence apart from another and from the series itself' do
      document.document_attachments.create!(attachable: event)
      document.document_attachments.create!(attachable: event, occurrence_date: Date.new(2026, 9, 15))
      document.document_attachments.create!(attachable: event, occurrence_date: Date.new(2026, 9, 22))

      expect(document.document_attachments.count).to eq(3)
    end

    it 'refuses a date on something that does not repeat' do
      plain = FactoryBot.create(:calendar_event, teacher: teacher)
      attachment = document.document_attachments.build(attachable: plain, occurrence_date: Date.current)

      expect(attachment).not_to be_valid
    end

    it 'refuses a date on an assignment, which has no occurrences at all' do
      assignment = FactoryBot.create(:assignment, teacher: teacher,
                                                  subject: FactoryBot.create(:subject, teacher: teacher))
      attachment = document.document_attachments.build(attachable: assignment,
                                                       occurrence_date: Date.current)

      expect(attachment).not_to be_valid
    end
  end

  # A tick already follows an occurrence that is edited out of its series. So
  # does a document: the alternative is a receipt disappearing off the event a
  # teacher is looking at, for a reason she cannot see.
  describe 'when an occurrence is edited out of its series' do
    it 'moves the filing onto the event that now stands for that date' do
      event = FactoryBot.create(:calendar_event, teacher: teacher)
      event.create_recurrence!(frequency: 'weekly', weekdays: [2])
      date = Date.new(2026, 9, 15)
      attachment = document.document_attachments.create!(attachable: event, occurrence_date: date)

      replacement = EventSeriesEdit
                    .new(event, occurrence_date: date, time_zone: 'America/New_York')
                    .detach({ 'title' => 'Moved to the afternoon' }, nil)

      attachment.reload
      expect(attachment.attachable).to eq(replacement)
      expect(attachment.occurrence_date).to be_nil
    end

    it 'moves the filing on a task the same way' do
      task = FactoryBot.create(:task, teacher: teacher, due_date: Date.new(2026, 9, 15))
      task.create_recurrence!(frequency: 'weekly', weekdays: [2])
      date = Date.new(2026, 9, 22)
      attachment = document.document_attachments.create!(attachable: task, occurrence_date: date)

      replacement = TaskSeriesEdit
                    .new(task, occurrence_date: date)
                    .detach({ 'title' => 'With the new bill' }, nil)

      attachment.reload
      expect(attachment.attachable).to eq(replacement)
      expect(attachment.occurrence_date).to be_nil
    end

    it 'leaves a filing on a different date where it was' do
      event = FactoryBot.create(:calendar_event, teacher: teacher)
      event.create_recurrence!(frequency: 'weekly', weekdays: [2])
      untouched = document.document_attachments.create!(attachable: event,
                                                        occurrence_date: Date.new(2026, 9, 29))

      EventSeriesEdit
        .new(event, occurrence_date: Date.new(2026, 9, 15), time_zone: 'America/New_York')
        .detach({ 'title' => 'Moved' }, nil)

      expect(untouched.reload.attachable).to eq(event)
      expect(untouched.occurrence_date).to eq(Date.new(2026, 9, 29))
    end
  end
end
