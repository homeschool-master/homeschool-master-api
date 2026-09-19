# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentGrade, type: :model do
  let(:teacher) { FactoryBot.create(:teacher) }
  let(:subject_record) { FactoryBot.create(:subject, teacher: teacher) }
  let(:assignment) do
    FactoryBot.create(:assignment, teacher: teacher, subject: subject_record, points_possible: 20)
  end
  let(:student) { FactoryBot.create(:student, teacher: teacher) }

  describe 'validations' do
    it 'is valid unmarked' do
      expect(FactoryBot.build(:assignment_grade, assignment: assignment, student: student)).to be_valid
    end

    it 'rejects a negative score' do
      grade = FactoryBot.build(:assignment_grade, assignment: assignment, student: student, points_earned: -1)
      expect(grade).not_to be_valid
    end

    it 'allows a score above points_possible, which is extra credit' do
      grade = FactoryBot.build(:assignment_grade, assignment: assignment, student: student, points_earned: 22)
      expect(grade).to be_valid
    end

    it 'allows one row per student per assignment' do
      FactoryBot.create(:assignment_grade, assignment: assignment, student: student)
      duplicate = FactoryBot.build(:assignment_grade, assignment: assignment, student: student)
      expect(duplicate).not_to be_valid
    end

    it 'rejects a student belonging to another teacher' do
      other = FactoryBot.create(:teacher)
      grade = FactoryBot.build(:assignment_grade, assignment: assignment,
                                                  student: FactoryBot.create(:student, teacher: other))
      expect(grade).not_to be_valid
      expect(grade.errors[:student_id]).to include('must belong to the current teacher')
    end
  end

  describe 'graded state' do
    it 'is ungraded while the score is null' do
      grade = FactoryBot.create(:assignment_grade, assignment: assignment, student: student)
      expect(grade.graded?).to be(false)
      expect(grade.graded_at).to be_nil
    end

    it 'is graded at zero, which is not the same as unmarked' do
      grade = FactoryBot.create(:assignment_grade, assignment: assignment, student: student, points_earned: 0)
      expect(grade.graded?).to be(true)
      expect(grade.fraction).to eq(0)
    end

    it 'stamps graded_at when a score is first entered' do
      grade = FactoryBot.create(:assignment_grade, assignment: assignment, student: student)
      grade.update!(points_earned: 15)
      expect(grade.reload.graded_at).to be_within(5.seconds).of(Time.current)
    end

    it 'clears graded_at when the score is removed' do
      grade = FactoryBot.create(:assignment_grade, assignment: assignment, student: student, points_earned: 15)
      grade.update!(points_earned: nil)
      expect(grade.reload.graded_at).to be_nil
    end

    it 'keeps the original graded_at when the score is corrected' do
      original = Time.utc(2026, 9, 1, 8, 0, 0)
      grade = FactoryBot.create(:assignment_grade, assignment: assignment, student: student,
                                                   points_earned: 15, graded_at: original)
      grade.update!(points_earned: 16)
      expect(grade.reload.graded_at).to eq(original)
    end
  end

  describe '#fraction' do
    it 'is nil while unmarked' do
      grade = FactoryBot.build(:assignment_grade, assignment: assignment, student: student)
      expect(grade.fraction).to be_nil
    end

    # 15 out of 20 is three quarters. Worked by hand, not by the code.
    it 'is the score over what the work is out of' do
      grade = FactoryBot.build(:assignment_grade, assignment: assignment, student: student, points_earned: 15)
      expect(grade.fraction).to eq(0.75)
    end

    it 'exceeds one for extra credit' do
      grade = FactoryBot.build(:assignment_grade, assignment: assignment, student: student, points_earned: 22)
      expect(grade.fraction).to eq(1.1)
    end
  end
end
