# frozen_string_literal: true

require 'rails_helper'

# Every expected number below is worked out by hand in the comment above it.
# Nothing here asks the calculation to confirm its own arithmetic.
RSpec.describe ProgressReport do
  let(:teacher) { FactoryBot.create(:teacher) }
  let(:student) { FactoryBot.create(:student, teacher: teacher) }
  let(:math) { FactoryBot.create(:subject, teacher: teacher, name: 'Math') }
  let(:science) { FactoryBot.create(:subject, teacher: teacher, name: 'Science') }

  let(:from) { Date.new(2026, 9, 1) }
  let(:to) { Date.new(2026, 9, 30) }

  def assignment(subject:, possible:, weight:, due: Date.new(2026, 9, 15), title: 'Work')
    FactoryBot.create(:assignment, teacher: teacher, subject: subject, title: title,
                                   points_possible: possible, weight: weight, due_date: due)
  end

  def score(assignment_record, earned, for_student: student)
    FactoryBot.create(:assignment_grade, assignment: assignment_record,
                                         student: for_student, points_earned: earned)
  end

  def report
    described_class.call(student: student, from: from, to: to)
  end

  def math_summary
    report[:subjects].find { |s| s[:subject_name] == 'Math' }
  end

  describe 'weighting' do
    # Two assignments, both out of 100, weights 1 and 3.
    #   quiz:  80/100 = 0.8, weight 1
    #   exam:  60/100 = 0.6, weight 3
    #   (1 * 0.8 + 3 * 0.6) / (1 + 3) = (0.8 + 1.8) / 4 = 2.6 / 4 = 0.65
    # So 65.0%. A plain mean of 80 and 60 would be 70, which is the point.
    it 'weights the exam three times the quiz' do
      score(assignment(subject: math, possible: 100, weight: 1, title: 'Quiz'), 80)
      score(assignment(subject: math, possible: 100, weight: 3, title: 'Exam'), 60)
      expect(math_summary[:percentage]).to eq(65.0)
      expect(math_summary[:percentage]).not_to eq(70.0)
    end

    # Weighting is on percentages, not raw points, so the totals do not decide it.
    #   quiz: 18/20 = 0.9, weight 1
    #   exam: 50/100 = 0.5, weight 1
    #   (0.9 + 0.5) / 2 = 0.7  ->  70.0%
    # Adding the points instead would give 68/120 = 56.67%, a different answer.
    it 'does not let the bigger point total quietly outweigh the smaller' do
      score(assignment(subject: math, possible: 20, weight: 1, title: 'Quiz'), 18)
      score(assignment(subject: math, possible: 100, weight: 1, title: 'Exam'), 50)
      expect(math_summary[:percentage]).to eq(70.0)
      expect(math_summary[:points_earned]).to eq(68)
      expect(math_summary[:points_possible]).to eq(120)
    end

    # A single assignment is its own percentage: 7/8 = 0.875 -> 87.5%.
    it 'handles a single assignment' do
      score(assignment(subject: math, possible: 8, weight: 1), 7)
      expect(math_summary[:percentage]).to eq(87.5)
    end

    # Weight 0 is practice: it contributes nothing to either side of the sum.
    #   counted: 40/100 = 0.4, weight 2  ->  (2 * 0.4) / 2 = 0.4  ->  40.0%
    it 'ignores work weighted zero' do
      score(assignment(subject: math, possible: 100, weight: 2, title: 'Counts'), 40)
      score(assignment(subject: math, possible: 100, weight: 0, title: 'Practice'), 100)
      expect(math_summary[:percentage]).to eq(40.0)
    end

    # Every assignment weighted zero leaves nothing to divide by. That is not a
    # student who scored nothing, so it reports no grade rather than 0%.
    it 'reports no percentage when every weight is zero' do
      score(assignment(subject: math, possible: 100, weight: 0), 100)
      expect(math_summary[:percentage]).to be_nil
      expect(math_summary[:letter]).to be_nil
      expect(math_summary[:graded_count]).to eq(1)
    end

    # Extra credit is allowed to push past 100.
    #   22/20 = 1.1  ->  110.0%
    it 'allows a percentage above one hundred' do
      score(assignment(subject: math, possible: 20, weight: 1), 22)
      expect(math_summary[:percentage]).to eq(110.0)
    end

    # Fractional weights work the same way.
    #   a: 100/100 = 1.0, weight 0.5
    #   b: 50/100  = 0.5, weight 1.5
    #   (0.5 * 1.0 + 1.5 * 0.5) / 2.0 = (0.5 + 0.75) / 2.0 = 1.25 / 2.0 = 0.625
    it 'handles fractional weights' do
      score(assignment(subject: math, possible: 100, weight: 0.5, title: 'Half'), 100)
      score(assignment(subject: math, possible: 100, weight: 1.5, title: 'Heavy'), 50)
      expect(math_summary[:percentage]).to eq(62.5)
    end
  end

  describe 'unmarked work' do
    # 90/100 marked, one assignment set but not marked.
    #   (1 * 0.9) / 1 = 0.9  ->  90.0%, and the unmarked one is counted, not averaged.
    it 'excludes unmarked work from the average rather than scoring it zero' do
      score(assignment(subject: math, possible: 100, weight: 1, title: 'Marked'), 90)
      FactoryBot.create(:assignment_grade,
                        assignment: assignment(subject: math, possible: 100, weight: 1, title: 'Unmarked'),
                        student: student, points_earned: nil)
      summary = math_summary
      expect(summary[:percentage]).to eq(90.0)
      expect(summary[:assigned_count]).to eq(2)
      expect(summary[:graded_count]).to eq(1)
      expect(summary[:ungraded_count]).to eq(1)
    end

    # An explicit zero is a real score and does drag the average.
    #   (1 * 0.9 + 1 * 0.0) / 2 = 0.45  ->  45.0%
    it 'counts an entered zero' do
      score(assignment(subject: math, possible: 100, weight: 1, title: 'Good'), 90)
      score(assignment(subject: math, possible: 100, weight: 1, title: 'Missed'), 0)
      expect(math_summary[:percentage]).to eq(45.0)
      expect(math_summary[:ungraded_count]).to eq(0)
    end

    it 'reports no grade for a subject where nothing has been marked' do
      FactoryBot.create(:assignment_grade,
                        assignment: assignment(subject: math, possible: 100, weight: 1),
                        student: student, points_earned: nil)
      expect(math_summary[:percentage]).to be_nil
      expect(math_summary[:letter]).to be_nil
    end
  end

  describe 'scoping' do
    it 'leaves out work due outside the period' do
      score(assignment(subject: math, possible: 100, weight: 1, due: Date.new(2026, 9, 10), title: 'In'), 100)
      score(assignment(subject: math, possible: 100, weight: 1, due: Date.new(2026, 10, 5), title: 'Out'), 0)
      expect(math_summary[:percentage]).to eq(100.0)
      expect(math_summary[:assigned_count]).to eq(1)
    end

    it 'includes work due on either boundary' do
      score(assignment(subject: math, possible: 100, weight: 1, due: from, title: 'First'), 100)
      score(assignment(subject: math, possible: 100, weight: 1, due: to, title: 'Last'), 50)
      expect(math_summary[:assigned_count]).to eq(2)
    end

    it 'leaves out undated work, which belongs to no period' do
      score(assignment(subject: math, possible: 100, weight: 1, due: nil), 100)
      expect(report[:subjects]).to be_empty
    end

    it "leaves out another student's scores" do
      shared = assignment(subject: math, possible: 100, weight: 1)
      other = FactoryBot.create(:student, teacher: teacher)
      score(shared, 100)
      score(shared, 20, for_student: other)
      expect(math_summary[:percentage]).to eq(100.0)
      expect(math_summary[:assigned_count]).to eq(1)
    end

    it 'leaves out work the student was never given' do
      assignment(subject: math, possible: 100, weight: 1)
      expect(report[:subjects]).to be_empty
    end
  end

  describe 'grouping and overall' do
    # Math:    (1 * 0.8 + 3 * 0.6) / 4 = 0.65   ->  65.0%
    # Science: (1 * 1.0) / 1          = 1.0     ->  100.0%
    # Overall weights every assignment the same way, not the subject averages:
    #   (1 * 0.8 + 3 * 0.6 + 1 * 1.0) / (1 + 3 + 1) = 3.6 / 5 = 0.72  ->  72.0%
    # Averaging the two subject figures instead would give (65 + 100) / 2 = 82.5.
    before do
      score(assignment(subject: math, possible: 100, weight: 1, title: 'Quiz'), 80)
      score(assignment(subject: math, possible: 100, weight: 3, title: 'Exam'), 60)
      score(assignment(subject: science, possible: 100, weight: 1, title: 'Lab'), 100)
    end

    it 'reports each subject separately' do
      expect(report[:subjects].map { |s| s[:subject_name] }).to eq(%w[Math Science])
      expect(math_summary[:percentage]).to eq(65.0)
      expect(report[:subjects].last[:percentage]).to eq(100.0)
    end

    it 'weights the overall figure by assignment, not by subject' do
      expect(report[:overall][:percentage]).to eq(72.0)
      expect(report[:overall][:percentage]).not_to eq(82.5)
    end

    it 'counts everything in the overall totals' do
      expect(report[:overall][:assigned_count]).to eq(3)
      expect(report[:overall][:graded_count]).to eq(3)
    end

    it 'orders subjects by name' do
      art = FactoryBot.create(:subject, teacher: teacher, name: 'Art')
      score(assignment(subject: art, possible: 100, weight: 1, title: 'Sketch'), 100)
      expect(report[:subjects].map { |s| s[:subject_name] }).to eq(%w[Art Math Science])
    end
  end

  describe 'letters' do
    # Boundaries are inclusive at the bottom of each band: 90 is an A, 89 a B.
    {
      100 => 'A', 90 => 'A', 89 => 'B', 80 => 'B', 79 => 'C',
      70 => 'C', 69 => 'D', 60 => 'D', 59 => 'F', 0 => 'F'
    }.each do |points, expected|
      it "grades #{points} out of 100 as #{expected}" do
        score(assignment(subject: math, possible: 100, weight: 1), points)
        expect(math_summary[:letter]).to eq(expected)
      end
    end

    it 'gives an A for extra credit above one hundred' do
      score(assignment(subject: math, possible: 20, weight: 1), 22)
      expect(math_summary[:letter]).to eq('A')
    end
  end

  describe 'rounding' do
    # 2/3 = 0.666... -> 66.67% to two places.
    it 'rounds the percentage to two places' do
      score(assignment(subject: math, possible: 3, weight: 1), 2)
      expect(math_summary[:percentage]).to eq(66.67)
    end
  end

  describe 'an empty report' do
    it 'reports no subjects and no overall grade' do
      result = report
      expect(result[:subjects]).to be_empty
      expect(result[:overall][:percentage]).to be_nil
      expect(result[:overall][:assigned_count]).to eq(0)
    end
  end
end
