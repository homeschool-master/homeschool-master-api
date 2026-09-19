# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assignment, type: :model do
  let(:teacher) { FactoryBot.create(:teacher) }
  let(:subject_record) { FactoryBot.create(:subject, teacher: teacher) }

  def build_assignment(**attrs)
    FactoryBot.build(:assignment, { teacher: teacher, subject: subject_record }.merge(attrs))
  end

  describe 'validations' do
    it 'is valid with a title, subject and points' do
      expect(build_assignment).to be_valid
    end

    it 'requires a title' do
      expect(build_assignment(title: '')).not_to be_valid
    end

    it 'rejects a title longer than 255 characters' do
      expect(build_assignment(title: 'a' * 256)).not_to be_valid
    end

    it 'requires points_possible above zero' do
      expect(build_assignment(points_possible: 0)).not_to be_valid
    end

    it 'rejects negative points_possible' do
      expect(build_assignment(points_possible: -5)).not_to be_valid
    end

    it 'allows a weight of zero, meaning practice that does not count' do
      expect(build_assignment(weight: 0)).to be_valid
    end

    it 'rejects a negative weight' do
      expect(build_assignment(weight: -1)).not_to be_valid
    end

    it "rejects another teacher's subject" do
      other = FactoryBot.create(:teacher)
      assignment = build_assignment(subject: FactoryBot.create(:subject, teacher: other))
      expect(assignment).not_to be_valid
      expect(assignment.errors[:subject_id]).to include('must belong to the current teacher')
    end

    it 'allows no due date' do
      expect(build_assignment(due_date: nil)).to be_valid
    end
  end

  describe 'associations' do
    it 'reaches students through their grades' do
      assignment = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record)
      student = FactoryBot.create(:student, teacher: teacher)
      FactoryBot.create(:assignment_grade, assignment: assignment, student: student)
      expect(assignment.students).to eq([student])
    end

    it 'takes its grades with it when destroyed' do
      assignment = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record)
      FactoryBot.create(:assignment_grade, assignment: assignment,
                                           student: FactoryBot.create(:student, teacher: teacher))
      expect { assignment.destroy }.to change(AssignmentGrade, :count).by(-1)
    end

    it 'goes with the teacher when the teacher is destroyed' do
      FactoryBot.create(:assignment, teacher: teacher, subject: subject_record)
      expect { teacher.destroy }.to change(described_class, :count).by(-1)
    end

    it 'goes with the subject when the subject is destroyed' do
      FactoryBot.create(:assignment, teacher: teacher, subject: subject_record)
      expect { subject_record.destroy }.to change(described_class, :count).by(-1)
    end

    it 'survives the removal a teacher can actually perform, which is a soft delete' do
      assignment = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record)
      subject_record.update!(is_active: false)
      expect(assignment.reload.subject).to eq(subject_record)
    end
  end

  describe 'scopes' do
    it 'due_between excludes undated work' do
      FactoryBot.create(:assignment, teacher: teacher, subject: subject_record, due_date: nil)
      dated = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record,
                                             due_date: Date.new(2026, 9, 15))
      expect(described_class.due_between(Date.new(2026, 1, 1), Date.new(2026, 12, 31))).to eq([dated])
    end

    it 'due_between is inclusive of both ends' do
      first = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record,
                                             due_date: Date.new(2026, 9, 1))
      last = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record,
                                            due_date: Date.new(2026, 9, 30))
      range = described_class.due_between(Date.new(2026, 9, 1), Date.new(2026, 9, 30))
      expect(range).to contain_exactly(first, last)
    end

    it 'chronological puts undated work last' do
      undated = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record,
                                               title: 'Undated', due_date: nil)
      soon = FactoryBot.create(:assignment, teacher: teacher, subject: subject_record,
                                            title: 'Soon', due_date: Date.new(2026, 9, 1))
      expect(described_class.chronological.to_a).to eq([soon, undated])
    end
  end
end
