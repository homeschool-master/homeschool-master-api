# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Students', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  describe 'GET /api/v1/students' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns success' do
        get api_v1_students_url
        expect(response).to have_http_status(:ok)
      end

      it "returns the teacher's active students" do
        FactoryBot.create(:student, teacher: @teacher, first_name: 'Emma')
        FactoryBot.create(:student, teacher: @teacher, first_name: 'Noah')
        get api_v1_students_url
        names = JSON.parse(response.body)['data'].map { |s| s['first_name'] }
        expect(names).to contain_exactly('Emma', 'Noah')
      end

      it 'excludes soft-deleted students' do
        FactoryBot.create(:student, teacher: @teacher, first_name: 'Active')
        FactoryBot.create(:student, teacher: @teacher, first_name: 'Removed', is_active: false)
        get api_v1_students_url
        names = JSON.parse(response.body)['data'].map { |s| s['first_name'] }
        expect(names).to eq(['Active'])
      end

      it "excludes other teachers' students" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        FactoryBot.create(:student, teacher: other, first_name: 'NotMine')
        FactoryBot.create(:student, teacher: @teacher, first_name: 'Mine')
        get api_v1_students_url
        names = JSON.parse(response.body)['data'].map { |s| s['first_name'] }
        expect(names).to eq(['Mine'])
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_students_url
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/students/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @student = FactoryBot.create(:student, teacher: @teacher)
        sign_in(@teacher)
      end

      it 'returns the student' do
        get api_v1_student_url(@student)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['id']).to eq(@student.id)
      end

      it 'returns not found when the student does not exist' do
        get api_v1_student_url('00000000-0000-0000-0000-000000000000')
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for another teacher's student" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_student = FactoryBot.create(:student, teacher: other)
        get api_v1_student_url(other_student)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        student = FactoryBot.create(:student)
        get api_v1_student_url(student)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/students' do
    let(:valid_params) do
      { first_name: 'Emma', last_name: 'Masters', grade_level: '5', color: '#7a322d' }
    end

    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns created' do
        post api_v1_students_url, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'creates a student for the teacher' do
        expect do
          post api_v1_students_url, params: valid_params
        end.to change(@teacher.students, :count).by(1)
      end

      it 'returns the created student payload' do
        post api_v1_students_url, params: valid_params
        data = JSON.parse(response.body)['data']
        expect(data['first_name']).to eq('Emma')
        expect(data['color']).to eq('#7a322d')
        expect(data['is_active']).to be(true)
      end

      it 'ignores an injected teacher_id' do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        post api_v1_students_url, params: valid_params.merge(teacher_id: other.id)
        expect(JSON.parse(response.body)['data']['teacher_id']).to eq(@teacher.id)
      end

      it 'returns a validation error when first name is blank' do
        post api_v1_students_url, params: valid_params.merge(first_name: '')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'allows a minimal body without grade or color' do
        post api_v1_students_url, params: { first_name: 'Sam', last_name: 'Masters' }
        data = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:created)
        expect(data['grade_level']).to be_nil
        expect(data['color']).to be_nil
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post api_v1_students_url, params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/students/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @student = FactoryBot.create(:student, teacher: @teacher, grade_level: '5', color: '#7a322d')
        sign_in(@teacher)
      end

      it 'updates the student' do
        patch api_v1_student_url(@student), params: { grade_level: '6', color: '#796123' }
        expect(response).to have_http_status(:ok)
        @student.reload
        expect(@student.grade_level).to eq('6')
        expect(@student.color).to eq('#796123')
      end

      it 'returns the updated payload' do
        patch api_v1_student_url(@student), params: { first_name: 'Emmaline' }
        expect(JSON.parse(response.body)['data']['first_name']).to eq('Emmaline')
      end

      it 'returns a validation error when first name is blank' do
        patch api_v1_student_url(@student), params: { first_name: '' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns not found for another teacher's student" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_student = FactoryBot.create(:student, teacher: other)
        patch api_v1_student_url(other_student), params: { grade_level: '6' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        student = FactoryBot.create(:student)
        patch api_v1_student_url(student), params: { grade_level: '6' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/students/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @student = FactoryBot.create(:student, teacher: @teacher)
        sign_in(@teacher)
      end

      it 'returns no content' do
        delete api_v1_student_url(@student)
        expect(response).to have_http_status(:no_content)
      end

      it 'soft deletes the student' do
        delete api_v1_student_url(@student)
        expect(@student.reload.is_active).to be(false)
      end

      it 'removes the student from the index' do
        delete api_v1_student_url(@student)
        get api_v1_students_url
        ids = JSON.parse(response.body)['data'].map { |s| s['id'] }
        expect(ids).not_to include(@student.id)
      end

      it "returns not found for another teacher's student" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_student = FactoryBot.create(:student, teacher: other)
        delete api_v1_student_url(other_student)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        student = FactoryBot.create(:student)
        delete api_v1_student_url(student)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
