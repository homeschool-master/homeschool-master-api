# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Teacher, type: :model do
  let(:first_name) { 'robert' }
  let(:last_name) { 'masters' }
  let(:email) { 'test@gmail.com' }
  let(:password) { 'testpassword' }
  let(:teacher) { Teacher.create!(first_name:, last_name:, email:, password:) }
  describe 'validations' do
    context 'when attributes are valid' do
      it 'creates a valid teacher' do
        expect(teacher).to be_valid
      end
    end
    # context 'when attributes are invalid' do
    #   context 'when first name is missing' do
    #     it 'is invalid' do
    #       expect(teacher).not_to be_valid
    #       expect(teacher.errors).to include("can't be blank")
    #     end
    #   end
    # end
  end
end
