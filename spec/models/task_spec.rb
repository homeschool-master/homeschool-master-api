# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:teacher) { FactoryBot.create(:teacher) }

  describe 'associations' do
    it 'belongs to a teacher' do
      expect(FactoryBot.create(:task, teacher: teacher).teacher).to eq(teacher)
    end

    it 'goes with the teacher when the teacher is destroyed' do
      FactoryBot.create(:task, teacher: teacher)
      expect { teacher.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'validations' do
    it 'is valid with a title' do
      expect(FactoryBot.build(:task, teacher: teacher, title: 'Export report cards')).to be_valid
    end

    it 'requires a title' do
      task = FactoryBot.build(:task, teacher: teacher, title: '')
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include("can't be blank")
    end

    it 'rejects a title longer than 255 characters' do
      expect(FactoryBot.build(:task, teacher: teacher, title: 'a' * 256)).not_to be_valid
    end

    it 'accepts a title of exactly 255 characters' do
      expect(FactoryBot.build(:task, teacher: teacher, title: 'a' * 255)).to be_valid
    end

    it 'allows no due date' do
      expect(FactoryBot.build(:task, :undated, teacher: teacher)).to be_valid
    end

    it 'allows a blank description' do
      expect(FactoryBot.build(:task, teacher: teacher, description: '')).to be_valid
    end

    it 'duplicate titles are fine, unlike subjects' do
      FactoryBot.create(:task, teacher: teacher, title: 'Email the co-op')
      expect(FactoryBot.build(:task, teacher: teacher, title: 'Email the co-op')).to be_valid
    end
  end

  describe 'callbacks' do
    it 'stores a blank description as nil' do
      task = FactoryBot.create(:task, teacher: teacher, description: '   ')
      expect(task.reload.description).to be_nil
    end
  end

  describe 'completion' do
    it 'is not completed when the timestamp is null' do
      expect(FactoryBot.build(:task, teacher: teacher).completed).to be(false)
    end

    it 'is completed when the timestamp is set' do
      expect(FactoryBot.build(:task, :completed, teacher: teacher).completed).to be(true)
    end

    it 'stamps the time when set to true' do
      task = FactoryBot.create(:task, teacher: teacher)
      task.update!(completed: true)
      expect(task.reload.completed_at).to be_within(5.seconds).of(Time.current)
    end

    it 'clears the time when set to false' do
      task = FactoryBot.create(:task, :completed, teacher: teacher)
      task.update!(completed: false)
      expect(task.reload.completed_at).to be_nil
    end

    it 'keeps the original time when completed again' do
      original = Time.utc(2026, 9, 1, 8, 0, 0)
      task = FactoryBot.create(:task, teacher: teacher, completed_at: original)
      task.update!(completed: true)
      expect(task.reload.completed_at).to eq(original)
    end

    it 'accepts the string true' do
      task = FactoryBot.create(:task, teacher: teacher)
      task.update!(completed: 'true')
      expect(task.reload.completed).to be(true)
    end

    it 'accepts the string false' do
      task = FactoryBot.create(:task, :completed, teacher: teacher)
      task.update!(completed: 'false')
      expect(task.reload.completed).to be(false)
    end

    it 'answers the predicate form too' do
      expect(FactoryBot.build(:task, :completed, teacher: teacher).completed?).to be(true)
    end
  end

  describe 'scopes' do
    before do
      @open_soon = FactoryBot.create(:task, teacher: teacher, title: 'Soon', due_date: Date.new(2026, 9, 20))
      @open_later = FactoryBot.create(:task, teacher: teacher, title: 'Later', due_date: Date.new(2026, 10, 5))
      @undated = FactoryBot.create(:task, :undated, teacher: teacher, title: 'Undated')
      @done = FactoryBot.create(:task, :completed, teacher: teacher, title: 'Done', due_date: Date.new(2026, 9, 19))
    end

    it 'open returns only unfinished tasks' do
      expect(teacher.tasks.open).to contain_exactly(@open_soon, @open_later, @undated)
    end

    it 'completed returns only finished tasks' do
      expect(teacher.tasks.completed).to eq([@done])
    end

    it 'due_by includes a task due on the boundary date' do
      expect(teacher.tasks.due_by(Date.new(2026, 9, 20))).to contain_exactly(@open_soon, @done)
    end

    it 'due_by excludes undated tasks' do
      expect(teacher.tasks.due_by(Date.new(2027, 1, 1))).not_to include(@undated)
    end

    it 'by_due_date orders soonest first with undated last' do
      expect(teacher.tasks.by_due_date.map(&:title)).to eq(%w[Done Soon Later Undated])
    end

    it 'breaks ties on due date by creation order' do
      first = FactoryBot.create(:task, teacher: teacher, title: 'First', due_date: Date.new(2026, 9, 21))
      second = FactoryBot.create(:task, teacher: teacher, title: 'Second', due_date: Date.new(2026, 9, 21))
      ordered = teacher.tasks.by_due_date.map(&:title)
      expect(ordered.index(first.title)).to be < ordered.index(second.title)
    end
  end

  describe 'students and ownership' do
    let(:teacher) { FactoryBot.create(:teacher) }
    let(:student) { FactoryBot.create(:student, teacher: teacher) }

    it 'defaults to the teacher\'s own' do
      expect(FactoryBot.create(:task, teacher: teacher).owned_by).to eq('teacher')
    end

    it 'rejects an owner outside the three it knows' do
      task = FactoryBot.build(:task, teacher: teacher, owned_by: 'nobody')
      expect(task).not_to be_valid
      expect(task.errors[:owned_by]).to be_present
    end

    it 'lets a teacher owned task name students' do
      task = FactoryBot.build(:task, teacher: teacher, owned_by: 'teacher', students: [student])
      expect(task).to be_valid
    end

    it 'lets a teacher owned task name nobody' do
      expect(FactoryBot.build(:task, teacher: teacher, owned_by: 'teacher')).to be_valid
    end

    # A task that is a student's has to say whose: an owner that names nobody
    # records something that does not exist.
    it 'refuses a student owned task that names nobody' do
      task = FactoryBot.build(:task, teacher: teacher, owned_by: 'student')
      expect(task).not_to be_valid
      expect(task.errors[:student_ids]).to be_present
    end

    it 'refuses a shared task that names nobody' do
      task = FactoryBot.build(:task, teacher: teacher, owned_by: 'both')
      expect(task).not_to be_valid
    end

    it 'accepts a student owned task that names one' do
      expect(FactoryBot.build(:task, teacher: teacher, owned_by: 'student', students: [student])).to be_valid
    end

    it 'refuses to have the last student taken off a student owned task' do
      task = FactoryBot.create(:task, teacher: teacher, owned_by: 'student', students: [student])
      task.students = []
      expect(task).not_to be_valid
    end

    it 'allows the last student off once the task is the teacher\'s again' do
      task = FactoryBot.create(:task, teacher: teacher, owned_by: 'student', students: [student])
      task.assign_attributes(owned_by: 'teacher')
      task.students = []
      expect(task).to be_valid
    end

    it 'reports whether a student is on the hook' do
      expect(FactoryBot.build(:task, owned_by: 'teacher')).not_to be_student_owned
      expect(FactoryBot.build(:task, owned_by: 'student')).to be_student_owned
      expect(FactoryBot.build(:task, owned_by: 'both')).to be_student_owned
    end
  end

  describe 'student scopes' do
    let(:teacher) { FactoryBot.create(:teacher) }

    it 'for_students returns tasks any of them are on' do
      eliza = FactoryBot.create(:student, teacher: teacher, first_name: 'Eliza')
      samuel = FactoryBot.create(:student, teacher: teacher, first_name: 'Samuel')
      ruth = FactoryBot.create(:student, teacher: teacher, first_name: 'Ruth')
      elizas = FactoryBot.create(:task, teacher: teacher, title: 'Elizas', students: [eliza])
      samuels = FactoryBot.create(:task, teacher: teacher, title: 'Samuels', students: [samuel])
      FactoryBot.create(:task, teacher: teacher, title: 'Ruths', students: [ruth])

      expect(teacher.tasks.for_students([eliza.id, samuel.id])).to contain_exactly(elizas, samuels)
    end

    it 'for_students returns a shared task once' do
      eliza = FactoryBot.create(:student, teacher: teacher, first_name: 'Eliza')
      samuel = FactoryBot.create(:student, teacher: teacher, first_name: 'Samuel')
      shared = FactoryBot.create(:task, teacher: teacher, students: [eliza, samuel])

      expect(teacher.tasks.for_students([eliza.id, samuel.id])).to eq([shared])
    end

    # The two ownership scopes answer whose job it is, which is a different
    # question from who the task names.
    it 'owned_by_teacher includes shared work but not a student\'s own' do
      student = FactoryBot.create(:student, teacher: teacher)
      mine = FactoryBot.create(:task, teacher: teacher, owned_by: 'teacher')
      shared = FactoryBot.create(:task, teacher: teacher, owned_by: 'both', students: [student])
      FactoryBot.create(:task, teacher: teacher, owned_by: 'student', students: [student])

      expect(teacher.tasks.owned_by_teacher).to contain_exactly(mine, shared)
    end

    it 'owned_by_student includes shared work but not the teacher\'s own' do
      student = FactoryBot.create(:student, teacher: teacher)
      FactoryBot.create(:task, teacher: teacher, owned_by: 'teacher')
      shared = FactoryBot.create(:task, teacher: teacher, owned_by: 'both', students: [student])
      theirs = FactoryBot.create(:task, teacher: teacher, owned_by: 'student', students: [student])

      expect(teacher.tasks.owned_by_student).to contain_exactly(shared, theirs)
    end
  end
end
