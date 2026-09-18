# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Subjects', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def names_in_response
    JSON.parse(response.body)['data'].map { |subject| subject['name'] }
  end

  describe 'GET /api/v1/subjects' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns success' do
        get api_v1_subjects_url
        expect(response).to have_http_status(:ok)
      end

      it "returns the teacher's active subjects, alphabetically" do
        FactoryBot.create(:subject, teacher: @teacher, name: 'Science')
        FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        get api_v1_subjects_url
        expect(names_in_response).to eq(%w[Math Science])
      end

      it 'excludes removed subjects' do
        FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        FactoryBot.create(:subject, teacher: @teacher, name: 'Latin', is_active: false)
        get api_v1_subjects_url
        expect(names_in_response).to eq(['Math'])
      end

      it "excludes other teachers' subjects" do
        other = FactoryBot.create(:teacher)
        FactoryBot.create(:subject, teacher: other, name: 'NotMine')
        FactoryBot.create(:subject, teacher: @teacher, name: 'Mine')
        get api_v1_subjects_url
        expect(names_in_response).to eq(['Mine'])
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_subjects_url
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/subjects/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @subject_record = FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        sign_in(@teacher)
      end

      it 'returns the subject' do
        get api_v1_subject_url(@subject_record)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['id']).to eq(@subject_record.id)
      end

      it 'returns not found when the subject does not exist' do
        get api_v1_subject_url('00000000-0000-0000-0000-000000000000')
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for another teacher's subject" do
        other = FactoryBot.create(:teacher)
        get api_v1_subject_url(FactoryBot.create(:subject, teacher: other))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_subject_url(FactoryBot.create(:subject))
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/subjects' do
    let(:valid_params) { { name: 'Math', color: '#d97b0a', description: 'Chapter work and drills' } }

    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns created' do
        post api_v1_subjects_url, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'creates a subject for the teacher' do
        expect do
          post api_v1_subjects_url, params: valid_params
        end.to change(@teacher.subjects, :count).by(1)
      end

      it 'returns the created payload' do
        post api_v1_subjects_url, params: valid_params
        data = JSON.parse(response.body)['data']
        expect(data['name']).to eq('Math')
        expect(data['color']).to eq('#d97b0a')
        expect(data['description']).to eq('Chapter work and drills')
        expect(data['is_active']).to be(true)
      end

      it 'ignores an injected teacher_id' do
        other = FactoryBot.create(:teacher)
        post api_v1_subjects_url, params: valid_params.merge(teacher_id: other.id)
        expect(JSON.parse(response.body)['data']['teacher_id']).to eq(@teacher.id)
      end

      it 'ignores an injected is_active' do
        post api_v1_subjects_url, params: valid_params.merge(is_active: false)
        expect(JSON.parse(response.body)['data']['is_active']).to be(true)
      end

      it 'allows a minimal body of just a name' do
        post api_v1_subjects_url, params: { name: 'Art' }
        data = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:created)
        expect(data['color']).to be_nil
        expect(data['description']).to be_nil
      end

      it 'returns a validation error when the name is blank' do
        post api_v1_subjects_url, params: valid_params.merge(name: '')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects a duplicate name for the same teacher' do
        FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        post api_v1_subjects_url, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['error']['details']['name']).to include('has already been taken')
      end

      it 'rejects a duplicate that differs only in case' do
        FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        post api_v1_subjects_url, params: valid_params.merge(name: 'math')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'creates nothing when the name is a duplicate' do
        FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        expect do
          post api_v1_subjects_url, params: valid_params
        end.not_to change(@teacher.subjects, :count)
      end

      it 'allows the same name under a different teacher' do
        other = FactoryBot.create(:teacher)
        FactoryBot.create(:subject, teacher: other, name: 'Math')
        post api_v1_subjects_url, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'allows the name again after the original is removed' do
        existing = FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        delete api_v1_subject_url(existing)
        post api_v1_subjects_url, params: valid_params
        expect(response).to have_http_status(:created)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post api_v1_subjects_url, params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/subjects/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @subject_record = FactoryBot.create(:subject, teacher: @teacher, name: 'Math', color: '#d97b0a')
        sign_in(@teacher)
      end

      it 'updates the subject' do
        patch api_v1_subject_url(@subject_record), params: { name: 'Mathematics', color: '#16a34a' }
        expect(response).to have_http_status(:ok)
        @subject_record.reload
        expect(@subject_record.name).to eq('Mathematics')
        expect(@subject_record.color).to eq('#16a34a')
      end

      it 'returns the updated payload' do
        patch api_v1_subject_url(@subject_record), params: { description: 'Now with geometry' }
        expect(JSON.parse(response.body)['data']['description']).to eq('Now with geometry')
      end

      it 'clears the description when sent blank' do
        patch api_v1_subject_url(@subject_record), params: { description: '' }
        expect(@subject_record.reload.description).to be_nil
      end

      it 'accepts an update that leaves the name unchanged' do
        patch api_v1_subject_url(@subject_record), params: { name: 'Math', color: '#16a34a' }
        expect(response).to have_http_status(:ok)
      end

      it 'returns a validation error when the name is blank' do
        patch api_v1_subject_url(@subject_record), params: { name: '' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects a rename onto another of the teacher's subjects" do
        FactoryBot.create(:subject, teacher: @teacher, name: 'Science')
        patch api_v1_subject_url(@subject_record), params: { name: 'Science' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'cannot be used to reactivate a subject' do
        @subject_record.update!(is_active: false)
        patch api_v1_subject_url(@subject_record), params: { is_active: true }
        expect(@subject_record.reload.is_active).to be(false)
      end

      it "returns not found for another teacher's subject" do
        other = FactoryBot.create(:teacher)
        patch api_v1_subject_url(FactoryBot.create(:subject, teacher: other)), params: { name: 'Hijacked' }
        expect(response).to have_http_status(:not_found)
      end

      it "leaves another teacher's subject untouched" do
        other = FactoryBot.create(:teacher)
        theirs = FactoryBot.create(:subject, teacher: other, name: 'Theirs')
        patch api_v1_subject_url(theirs), params: { name: 'Hijacked' }
        expect(theirs.reload.name).to eq('Theirs')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_subject_url(FactoryBot.create(:subject)), params: { name: 'Nope' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/subjects/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @subject_record = FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        sign_in(@teacher)
      end

      it 'returns no content' do
        delete api_v1_subject_url(@subject_record)
        expect(response).to have_http_status(:no_content)
      end

      it 'soft deletes rather than destroying the row' do
        expect do
          delete api_v1_subject_url(@subject_record)
        end.not_to change(Subject, :count)
        expect(@subject_record.reload.is_active).to be(false)
      end

      it 'removes the subject from the index' do
        delete api_v1_subject_url(@subject_record)
        get api_v1_subjects_url
        expect(names_in_response).not_to include('Math')
      end

      it "returns not found for another teacher's subject" do
        other = FactoryBot.create(:teacher)
        delete api_v1_subject_url(FactoryBot.create(:subject, teacher: other))
        expect(response).to have_http_status(:not_found)
      end

      it "leaves another teacher's subject active" do
        other = FactoryBot.create(:teacher)
        theirs = FactoryBot.create(:subject, teacher: other)
        delete api_v1_subject_url(theirs)
        expect(theirs.reload.is_active).to be(true)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        delete api_v1_subject_url(FactoryBot.create(:subject))
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
