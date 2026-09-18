# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subject, type: :model do
  let(:teacher) { FactoryBot.create(:teacher) }

  describe 'associations' do
    it 'belongs to a teacher' do
      expect(FactoryBot.create(:subject, teacher: teacher).teacher).to eq(teacher)
    end

    it 'goes with the teacher when the teacher is destroyed' do
      FactoryBot.create(:subject, teacher: teacher)
      expect { teacher.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'validations' do
    it 'is valid with a name' do
      expect(FactoryBot.build(:subject, teacher: teacher, name: 'Math')).to be_valid
    end

    it 'requires a name' do
      subject_record = FactoryBot.build(:subject, teacher: teacher, name: '')
      expect(subject_record).not_to be_valid
      expect(subject_record.errors[:name]).to include("can't be blank")
    end

    it 'rejects a name longer than 100 characters' do
      expect(FactoryBot.build(:subject, teacher: teacher, name: 'a' * 101)).not_to be_valid
    end

    it 'accepts a name of exactly 100 characters' do
      expect(FactoryBot.build(:subject, teacher: teacher, name: 'a' * 100)).to be_valid
    end

    it 'rejects a color longer than 20 characters' do
      expect(FactoryBot.build(:subject, teacher: teacher, color: 'a' * 21)).not_to be_valid
    end

    it 'allows a blank color' do
      expect(FactoryBot.build(:subject, teacher: teacher, color: '')).to be_valid
    end

    it 'allows a blank description' do
      expect(FactoryBot.build(:subject, teacher: teacher, description: '')).to be_valid
    end
  end

  describe 'name uniqueness' do
    before { FactoryBot.create(:subject, teacher: teacher, name: 'Math') }

    it 'rejects a duplicate name for the same teacher' do
      duplicate = FactoryBot.build(:subject, teacher: teacher, name: 'Math')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'rejects a duplicate that differs only in case' do
      expect(FactoryBot.build(:subject, teacher: teacher, name: 'math')).not_to be_valid
    end

    it 'allows the same name for a different teacher' do
      other = FactoryBot.create(:teacher)
      expect(FactoryBot.build(:subject, teacher: other, name: 'Math')).to be_valid
    end

    it 'allows the name again once the original is removed' do
      teacher.subjects.find_by(name: 'Math').update!(is_active: false)
      expect(FactoryBot.build(:subject, teacher: teacher, name: 'Math')).to be_valid
    end

    it 'lets a subject keep its own name when updated' do
      existing = teacher.subjects.find_by(name: 'Math')
      expect(existing.update(color: '#16a34a')).to be(true)
    end
  end

  describe 'database constraints' do
    it 'refuses a duplicate active name even when validation is skipped' do
      FactoryBot.create(:subject, teacher: teacher, name: 'Science')
      duplicate = FactoryBot.build(:subject, teacher: teacher, name: 'science')
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'permits a removed duplicate at the database level' do
      FactoryBot.create(:subject, teacher: teacher, name: 'Science')
      removed = FactoryBot.build(:subject, teacher: teacher, name: 'Science', is_active: false)
      expect { removed.save(validate: false) }.not_to raise_error
    end
  end

  describe 'callbacks' do
    it 'stores a blank description as nil' do
      record = FactoryBot.create(:subject, teacher: teacher, description: '   ')
      expect(record.reload.description).to be_nil
    end
  end

  describe 'scopes' do
    it 'returns only active subjects' do
      active = FactoryBot.create(:subject, teacher: teacher, name: 'Active')
      FactoryBot.create(:subject, teacher: teacher, name: 'Removed', is_active: false)
      expect(teacher.subjects.active).to eq([active])
    end
  end
end
