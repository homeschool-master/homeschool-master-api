# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentTypeDefaultWeight do
  let(:teacher) { FactoryBot.create(:teacher) }
  let(:subject_record) { FactoryBot.create(:subject, teacher: teacher) }
  let(:test_type) { teacher.assignment_types.find_by(name: 'Test') }

  # Whether a weight is the teacher's own is now a decision rather than
  # something inferred from the number, so a test that means "she typed this
  # one" says so, the same way the endpoint does.
  def assignment(weight:, due: Date.new(2026, 9, 1), type: test_type, overridden: false)
    record = FactoryBot.build(:assignment, teacher: teacher, subject: subject_record,
                                           assignment_type: type, due_date: due)
    overridden ? record.override_weight!(weight) : record.assign_attributes(weight: weight)
    record.save!
    record
  end

  describe 'new_only' do
    it 'changes the default and leaves every existing assignment where it is' do
      inherited = assignment(weight: 1)

      described_class.call(type: test_type, weight: 3, mode: 'new_only')

      expect(test_type.reload.default_weight).to eq(3)
      expect(inherited.reload.weight).to eq(1)
    end

    it 'reports that it touched nothing' do
      assignment(weight: 1)
      result = described_class.call(type: test_type, weight: 3, mode: 'new_only')

      expect(result.updated_count).to eq(0)
    end

    # The assignment is still inherited, so a later "all" does reach it. What
    # new_only means is "not now", not "pin this forever".
    it 'leaves the assignment inheriting, so a later change for all still reaches it' do
      inherited = assignment(weight: 1)

      described_class.call(type: test_type, weight: 3, mode: 'new_only')
      described_class.call(type: test_type, weight: 4, mode: 'all')

      expect(inherited.reload.weight).to eq(4)
    end
  end

  describe 'all' do
    it 'moves every assignment of that type that never had a weight of its own' do
      inherited = assignment(weight: 1)

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(inherited.reload.weight).to eq(3)
    end

    it 'includes work due before today, since past work is what "all" means' do
      old = assignment(weight: 1, due: Date.new(2020, 1, 1))

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(old.reload.weight).to eq(3)
    end

    it 'includes undated work' do
      undated = assignment(weight: 1, due: nil)

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(undated.reload.weight).to eq(3)
    end

    it 'leaves another type alone' do
      quiz = assignment(weight: 1, type: teacher.assignment_types.find_by(name: 'Quiz'))

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(quiz.reload.weight).to eq(1)
    end

    it 'leaves another teacher alone' do
      other = FactoryBot.create(:teacher)
      other_subject = FactoryBot.create(:subject, teacher: other)
      other_test = FactoryBot.create(:assignment, teacher: other, subject: other_subject,
                                                  assignment_type: other.assignment_types.find_by(name: 'Test'),
                                                  weight: 1)

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(other_test.reload.weight).to eq(1)
    end
  end

  describe 'from_date' do
    it 'moves work due on the date and after it' do
      on_the_day = assignment(weight: 1, due: Date.new(2026, 8, 1))
      later = assignment(weight: 1, due: Date.new(2026, 9, 20))

      described_class.call(type: test_type, weight: 3, mode: 'from_date', from_date: Date.new(2026, 8, 1))

      expect(on_the_day.reload.weight).to eq(3)
      expect(later.reload.weight).to eq(3)
    end

    it 'leaves work due before the date on the weight it had' do
      earlier = assignment(weight: 1, due: Date.new(2026, 7, 31))

      described_class.call(type: test_type, weight: 3, mode: 'from_date', from_date: Date.new(2026, 8, 1))

      expect(earlier.reload.weight).to eq(1)
    end

    # Undated work sits in no period, so a change described by a period does
    # not describe it. Same rule the progress report uses for its date range.
    it 'leaves undated work alone, since it belongs to no period' do
      undated = assignment(weight: 1, due: nil)

      described_class.call(type: test_type, weight: 3, mode: 'from_date', from_date: Date.new(2026, 8, 1))

      expect(undated.reload.weight).to eq(1)
    end

    it 'reports how many it moved' do
      assignment(weight: 1, due: Date.new(2026, 9, 1))
      assignment(weight: 1, due: Date.new(2026, 7, 1))

      result = described_class.call(type: test_type, weight: 3, mode: 'from_date',
                                    from_date: Date.new(2026, 8, 1))

      expect(result.updated_count).to eq(1)
    end
  end

  # The question the whole schema was shaped around.
  describe 'an assignment whose weight the teacher set by hand' do
    it 'keeps its weight when the default changes for all' do
      overridden = assignment(weight: 5, overridden: true)

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(overridden.reload.weight).to eq(5)
    end

    it 'keeps its weight when the default changes from a date it falls after' do
      overridden = assignment(weight: 5, due: Date.new(2026, 9, 1), overridden: true)

      described_class.call(type: test_type, weight: 3, mode: 'from_date', from_date: Date.new(2026, 8, 1))

      expect(overridden.reload.weight).to eq(5)
    end

    it 'keeps its weight through a run of default changes' do
      overridden = assignment(weight: 5, overridden: true)

      described_class.call(type: test_type, weight: 3, mode: 'all')
      described_class.call(type: test_type, weight: 2, mode: 'all')
      described_class.call(type: test_type, weight: 4, mode: 'from_date', from_date: Date.new(2020, 1, 1))

      expect(overridden.reload.weight).to eq(5)
    end

    it 'is recorded as overridden the moment the teacher sets one' do
      expect(assignment(weight: 5, overridden: true).weight_overridden).to be(true)
      expect(assignment(weight: 1).weight_overridden).to be(false)
    end

    # The case the old rule got wrong: typing the number the default already
    # says is still her choosing it, and a later change to that default must
    # not move work she had settled.
    it 'counts a weight she typed as hers even when it equals the default' do
      test_type.update!(default_weight: 3)
      same_as_default = assignment(weight: 3, overridden: true)

      expect(same_as_default.weight_overridden).to be(true)

      described_class.call(type: test_type, weight: 5, mode: 'all')

      expect(same_as_default.reload.weight).to eq(3)
    end

    it 'follows the default again once it is handed back' do
      one = assignment(weight: 5, overridden: true)
      one.inherit_weight!
      one.save!

      expect(one.reload.weight_overridden).to be(false)
      expect(one.weight).to eq(test_type.reload.default_weight)

      described_class.call(type: test_type, weight: 4, mode: 'all')

      expect(one.reload.weight).to eq(4)
    end

    it 'is not pinned by an edit that leaves the weight alone' do
      inherited = assignment(weight: 1)
      inherited.update!(title: 'Renamed')

      described_class.call(type: test_type, weight: 3, mode: 'all')

      expect(inherited.reload.weight).to eq(3)
    end
  end
end
