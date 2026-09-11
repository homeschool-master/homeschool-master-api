# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Preferences', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def json_data
    JSON.parse(response.body)['data']
  end

  describe 'PATCH /api/v1/profile/preferences' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns success' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon' }
        expect(response).to have_http_status(:ok)
      end

      it 'updates the time zone without a current password' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon' }
        expect(@teacher.reload.time_zone).to eq('Europe/Lisbon')
      end

      it 'returns the raw and effective zones' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon' }
        expect(json_data['time_zone']).to eq('Europe/Lisbon')
        expect(json_data['effective_time_zone']).to eq('Europe/Lisbon')
      end

      it 'replaces an existing zone' do
        @teacher.update!(time_zone: 'Asia/Tokyo')
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon' }
        expect(@teacher.reload.time_zone).to eq('Europe/Lisbon')
      end

      it 'ignores a submitted current_password rather than requiring one' do
        patch api_v1_profile_preferences_url,
              params: { time_zone: 'Europe/Lisbon', current_password: 'wrong' }
        expect(response).to have_http_status(:ok)
        expect(@teacher.reload.time_zone).to eq('Europe/Lisbon')
      end

      it 'rejects an unrecognized IANA zone' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Mars/Olympus_Mons' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects a Rails style zone name' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Eastern Time (US & Canada)' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'reports the zone error' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Mars/Olympus_Mons' }
        details = JSON.parse(response.body)['error']['details']
        expect(details['time_zone']).to include('is not a recognized IANA time zone')
      end

      it 'leaves the stored zone alone when the new one is rejected' do
        @teacher.update!(time_zone: 'Asia/Tokyo')
        patch api_v1_profile_preferences_url, params: { time_zone: 'Mars/Olympus_Mons' }
        expect(@teacher.reload.time_zone).to eq('Asia/Tokyo')
      end

      it 'does not accept identity fields' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon', first_name: 'Hijacked' }
        expect(@teacher.reload.first_name).not_to eq('Hijacked')
      end

      it 'does not accept an email change' do
        original = @teacher.email
        patch api_v1_profile_preferences_url,
              params: { time_zone: 'Europe/Lisbon', email: 'new@example.com' }
        expect(@teacher.reload.email).to eq(original)
      end

      it "only ever writes the current teacher's record" do
        other = FactoryBot.create(:teacher, email: 'other@example.com', time_zone: 'Asia/Tokyo')
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon', id: other.id }
        expect(other.reload.time_zone).to eq('Asia/Tokyo')
        expect(@teacher.reload.time_zone).to eq('Europe/Lisbon')
      end

      it "cannot target another teacher's record by teacher_id" do
        other = FactoryBot.create(:teacher, email: 'other@example.com', time_zone: 'Asia/Tokyo')
        patch api_v1_profile_preferences_url,
              params: { time_zone: 'Europe/Lisbon', teacher_id: other.id }
        expect(other.reload.time_zone).to eq('Asia/Tokyo')
      end

      it 'leaves the zone alone when the request body is empty' do
        @teacher.update!(time_zone: 'Asia/Tokyo')
        patch api_v1_profile_preferences_url, params: {}
        expect(response).to have_http_status(:ok)
        expect(@teacher.reload.time_zone).to eq('Asia/Tokyo')
      end

      it 'serializes a null raw zone for a teacher who has never set one' do
        patch api_v1_profile_preferences_url, params: {}
        expect(json_data['time_zone']).to be_nil
        expect(json_data['effective_time_zone']).to eq('America/New_York')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not change the stored zone' do
        teacher = FactoryBot.create(:teacher, time_zone: 'Asia/Tokyo')
        patch api_v1_profile_preferences_url, params: { time_zone: 'Europe/Lisbon' }
        expect(teacher.reload.time_zone).to eq('Asia/Tokyo')
      end
    end
  end
end
