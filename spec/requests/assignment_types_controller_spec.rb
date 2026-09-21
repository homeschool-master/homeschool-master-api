# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::AssignmentTypes', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def names_in_response
    JSON.parse(response.body)['data'].map { |type| type['name'] }
  end

  def body
    JSON.parse(response.body)
  end

  describe 'GET /api/v1/assignment_types' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
    end

    it 'gives a new teacher the three built in types' do
      get api_v1_assignment_types_url
      expect(names_in_response).to eq(%w[Assignment Quiz Test])
    end

    it 'starts every built in type at a weight of one, so grades behave as they did' do
      get api_v1_assignment_types_url
      expect(body['data'].map { |type| type['default_weight'].to_f }).to all(eq(1.0))
    end

    it 'lists the built in ones first, then the custom ones alphabetically' do
      FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration')
      FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Lab Report')

      get api_v1_assignment_types_url
      expect(names_in_response).to eq(['Assignment', 'Quiz', 'Test', 'Lab Report', 'Narration'])
    end

    it 'leaves out a removed type' do
      FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration', is_active: false)

      get api_v1_assignment_types_url
      expect(names_in_response).not_to include('Narration')
    end
  end

  context 'when not authenticated' do
    it 'returns unauthorized' do
      get api_v1_assignment_types_url
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # A custom type is one family's vocabulary. Another teacher must not see it,
  # reach it, or be blocked from using the same name.
  describe 'custom types are the teacher\'s own' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @other = FactoryBot.create(:teacher)
      @theirs = FactoryBot.create(:assignment_type, teacher: @other, name: 'Narration')
    end

    it 'does not list another teacher\'s type' do
      sign_in(@teacher)
      get api_v1_assignment_types_url
      expect(names_in_response).not_to include('Narration')
    end

    it 'refuses to update another teacher\'s type' do
      sign_in(@teacher)
      patch api_v1_assignment_type_url(@theirs), params: { name: 'Stolen' }

      expect(response).to have_http_status(:not_found)
      expect(@theirs.reload.name).to eq('Narration')
    end

    it 'refuses to remove another teacher\'s type' do
      sign_in(@teacher)
      delete api_v1_assignment_type_url(@theirs)

      expect(response).to have_http_status(:not_found)
      expect(@theirs.reload.is_active).to be(true)
    end

    it 'lets two teachers use the same name' do
      sign_in(@teacher)
      post api_v1_assignment_types_url, params: { name: 'Narration' }

      expect(response).to have_http_status(:created)
    end

    it 'refuses an assignment pointed at another teacher\'s type' do
      sign_in(@teacher)
      subject_record = FactoryBot.create(:subject, teacher: @teacher)
      post api_v1_assignments_url, params: {
        subject_id: subject_record.id, assignment_type_id: @theirs.id, title: 'Essay'
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']['details']).to have_key('assignment_type_id')
    end
  end

  describe 'POST /api/v1/assignment_types' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
    end

    it 'creates a custom type' do
      post api_v1_assignment_types_url, params: { name: 'Narration' }

      expect(response).to have_http_status(:created)
      expect(body['data']['is_built_in']).to be(false)
    end

    it 'starts a custom type at a weight of one' do
      post api_v1_assignment_types_url, params: { name: 'Narration' }
      expect(body['data']['default_weight'].to_f).to eq(1.0)
    end

    it 'takes a default weight on creation' do
      post api_v1_assignment_types_url, params: { name: 'Lab Report', default_weight: 2 }
      expect(body['data']['default_weight'].to_f).to eq(2.0)
    end

    it 'refuses a duplicate name whatever its case' do
      FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration')
      post api_v1_assignment_types_url, params: { name: 'narration' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a name a built in type already has' do
      post api_v1_assignment_types_url, params: { name: 'quiz' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'allows a name released by a removed type' do
      FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration', is_active: false)
      post api_v1_assignment_types_url, params: { name: 'Narration' }

      expect(response).to have_http_status(:created)
    end

    it 'refuses a blank name' do
      post api_v1_assignment_types_url, params: { name: '  ' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/assignment_types/:id' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
      @subject = FactoryBot.create(:subject, teacher: @teacher)
      @test = @teacher.assignment_types.find_by(name: 'Test')
    end

    def a_test(weight:, due: Date.new(2026, 9, 1), overridden: false)
      record = FactoryBot.build(:assignment, teacher: @teacher, subject: @subject,
                                             assignment_type: @test, due_date: due)
      overridden ? record.override_weight!(weight) : record.assign_attributes(weight: weight)
      record.save!
      record
    end

    it 'renames a custom type' do
      custom = FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration')
      patch api_v1_assignment_type_url(custom), params: { name: 'Oral Narration' }

      expect(response).to have_http_status(:ok)
      expect(custom.reload.name).to eq('Oral Narration')
    end

    it 'refuses to rename a built in type, since assignments already point at the name' do
      patch api_v1_assignment_type_url(@test), params: { name: 'Exam' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(@test.reload.name).to eq('Test')
    end

    it 'changes the default for new work only when no mode is given' do
      existing = a_test(weight: 1)
      patch api_v1_assignment_type_url(@test), params: { default_weight: 3 }

      expect(@test.reload.default_weight).to eq(3)
      expect(existing.reload.weight).to eq(1)
    end

    it 'changes every inherited assignment under the all mode' do
      existing = a_test(weight: 1)
      patch api_v1_assignment_type_url(@test), params: { default_weight: 3, apply_mode: 'all' }

      expect(existing.reload.weight).to eq(3)
      expect(body['data']['updated_count']).to eq(1)
    end

    it 'changes only work due from the date onward' do
      before_date = a_test(weight: 1, due: Date.new(2026, 7, 1))
      after_date = a_test(weight: 1, due: Date.new(2026, 8, 1))

      patch api_v1_assignment_type_url(@test), params: {
        default_weight: 3, apply_mode: 'from_date', from_date: '2026-08-01'
      }

      expect(before_date.reload.weight).to eq(1)
      expect(after_date.reload.weight).to eq(3)
    end

    it 'leaves a hand set weight alone whatever the mode' do
      overridden = a_test(weight: 5, overridden: true)
      patch api_v1_assignment_type_url(@test), params: { default_weight: 3, apply_mode: 'all' }

      expect(overridden.reload.weight).to eq(5)
    end

    it 'refuses a mode it does not know' do
      patch api_v1_assignment_type_url(@test), params: { default_weight: 3, apply_mode: 'everything' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']['details']).to have_key('apply_mode')
    end

    it 'refuses the date mode with no date' do
      patch api_v1_assignment_type_url(@test), params: { default_weight: 3, apply_mode: 'from_date' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']['details']).to have_key('from_date')
    end

    it 'refuses a negative default weight' do
      patch api_v1_assignment_type_url(@test), params: { default_weight: -1 }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'allows a default weight of zero, for work that is recorded but does not count' do
      patch api_v1_assignment_type_url(@test), params: { default_weight: 0 }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/assignment_types/:id' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
    end

    it 'removes a custom type without deleting its row' do
      custom = FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration')
      delete api_v1_assignment_type_url(custom)

      expect(response).to have_http_status(:no_content)
      expect(custom.reload.is_active).to be(false)
    end

    it 'leaves the assignments that point at a removed type readable' do
      custom = FactoryBot.create(:assignment_type, teacher: @teacher, name: 'Narration')
      work = FactoryBot.create(:assignment, teacher: @teacher,
                                            subject: FactoryBot.create(:subject, teacher: @teacher),
                                            assignment_type: custom)

      delete api_v1_assignment_type_url(custom)
      get api_v1_assignment_url(work)

      expect(body['data']['assignment_type_name']).to eq('Narration')
    end

    it 'refuses to remove a built in type' do
      built_in = @teacher.assignment_types.find_by(name: 'Quiz')
      delete api_v1_assignment_type_url(built_in)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(built_in.reload.is_active).to be(true)
    end
  end
end
