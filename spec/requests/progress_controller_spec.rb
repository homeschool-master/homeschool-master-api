# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Progress', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def data
    JSON.parse(response.body)['data']
  end

  context 'when authenticated' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @student = FactoryBot.create(:student, teacher: @teacher)
      @math = FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
      sign_in(@teacher)
    end

    def graded(points_possible:, weight:, earned:, due: Date.new(2026, 9, 15))
      assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @math,
                                                  points_possible: points_possible,
                                                  weight: weight, due_date: due)
      FactoryBot.create(:assignment_grade, assignment: assignment, student: @student, points_earned: earned)
    end

    # (1 * 0.8 + 3 * 0.6) / 4 = 0.65 -> 65.0, which is a D on the 90/80/70/60
    # scale: 65 clears 60 and not 70.
    it 'returns the weighted figure over the wire' do
      graded(points_possible: 100, weight: 1, earned: 80)
      graded(points_possible: 100, weight: 3, earned: 60)
      get api_v1_student_progress_url(@student), params: { from: '2026-09-01', to: '2026-09-30' }
      expect(response).to have_http_status(:ok)
      subject_row = data['subjects'].first
      expect(subject_row['subject_name']).to eq('Math')
      expect(subject_row['percentage'].to_f).to eq(65.0)
      expect(subject_row['letter']).to eq('D')
      expect(data['overall']['percentage'].to_f).to eq(65.0)
    end

    it 'reports counts so the reader knows what the figure covers' do
      graded(points_possible: 100, weight: 1, earned: 80)
      FactoryBot.create(:assignment_grade,
                        assignment: FactoryBot.create(:assignment, teacher: @teacher, subject: @math,
                                                                   due_date: Date.new(2026, 9, 15)),
                        student: @student, points_earned: nil)
      get api_v1_student_progress_url(@student), params: { from: '2026-09-01', to: '2026-09-30' }
      row = data['subjects'].first
      expect(row['assigned_count']).to eq(2)
      expect(row['graded_count']).to eq(1)
      expect(row['ungraded_count']).to eq(1)
    end

    it 'returns an empty report rather than an error when there is nothing yet' do
      get api_v1_student_progress_url(@student), params: { from: '2026-09-01', to: '2026-09-30' }
      expect(response).to have_http_status(:ok)
      expect(data['subjects']).to be_empty
      expect(data['overall']['percentage']).to be_nil
    end

    it 'requires from' do
      get api_v1_student_progress_url(@student), params: { to: '2026-09-30' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['details']['from']).to include('is required')
    end

    it 'requires to' do
      get api_v1_student_progress_url(@student), params: { from: '2026-09-01' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an unparseable date' do
      get api_v1_student_progress_url(@student), params: { from: 'term one', to: '2026-09-30' }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a range that runs backwards' do
      get api_v1_student_progress_url(@student), params: { from: '2026-09-30', to: '2026-09-01' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['details']['to']).to include('must be on or after from')
    end

    it "returns not found for another teacher's student" do
      other_student = FactoryBot.create(:student, teacher: FactoryBot.create(:teacher))
      get api_v1_student_progress_url(other_student), params: { from: '2026-09-01', to: '2026-09-30' }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for a student that does not exist' do
      get api_v1_student_progress_url('00000000-0000-0000-0000-000000000000'),
          params: { from: '2026-09-01', to: '2026-09-30' }
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when not authenticated' do
    it 'returns unauthorized' do
      student = FactoryBot.create(:student)
      get api_v1_student_progress_url(student), params: { from: '2026-09-01', to: '2026-09-30' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
