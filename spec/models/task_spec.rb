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
end
