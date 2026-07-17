# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Student, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:teacher) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_length_of(:first_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:middle_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:last_name).is_at_most(100) }
    it { is_expected.to validate_length_of(:grade_level).is_at_most(50) }
    it { is_expected.to validate_length_of(:color).is_at_most(20) }

    it 'is valid without a middle name' do
      student = FactoryBot.build(:student, middle_name: nil)
      expect(student).to be_valid
    end

    it 'is valid without a grade level or color' do
      student = FactoryBot.build(:student, grade_level: nil, color: nil)
      expect(student).to be_valid
    end

    it 'is not valid without a teacher' do
      student = FactoryBot.build(:student, teacher: nil)
      expect(student).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'is active when created' do
      student = FactoryBot.create(:student)
      expect(student.is_active).to be(true)
    end
  end

  describe 'callbacks' do
    it 'nullifies a blank middle name' do
      student = FactoryBot.create(:student, middle_name: '   ')
      expect(student.middle_name).to be_nil
    end

    it 'nullifies an empty middle name' do
      student = FactoryBot.create(:student, middle_name: '')
      expect(student.middle_name).to be_nil
    end

    it 'keeps a real middle name' do
      student = FactoryBot.create(:student, :with_middle_name)
      expect(student.middle_name).to eq('Rose')
    end

    it 'nullifies a middle name cleared on update' do
      student = FactoryBot.create(:student, :with_middle_name)
      student.update!(middle_name: '')
      expect(student.reload.middle_name).to be_nil
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'includes active students' do
        student = FactoryBot.create(:student)
        expect(described_class.active).to include(student)
      end

      it 'excludes soft-deleted students' do
        student = FactoryBot.create(:student, is_active: false)
        expect(described_class.active).not_to include(student)
      end
    end
  end

  describe '#full_name' do
    it 'joins the first and last name' do
      student = FactoryBot.build(:student, first_name: 'Emma', last_name: 'Masters')
      expect(student.full_name).to eq('Emma Masters')
    end
  end
end
