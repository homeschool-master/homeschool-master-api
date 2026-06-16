# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Profile', type: :request do
  context 'PATCH /api/v1/profile' do
    describe 'when authenticated with the correct password' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns success' do
        patch api_v1_profile_url,
              params: { first_name: 'New', last_name: 'Name', current_password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it 'updates the first and last name' do
        patch api_v1_profile_url,
              params: { first_name: 'New', last_name: 'Name', current_password: 'password123' }
        @teacher.reload
        expect(@teacher.first_name).to eq('New')
        expect(@teacher.last_name).to eq('Name')
      end

      it 'returns the updated user payload' do
        patch api_v1_profile_url,
              params: { first_name: 'New', last_name: 'Name', current_password: 'password123' }
        json_response = JSON.parse(response.body)
        expect(json_response['data']['first_name']).to eq('New')
        expect(json_response['data']['last_name']).to eq('Name')
      end
    end

    describe 'when the current password is wrong' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns unauthorized' do
        patch api_v1_profile_url,
              params: { first_name: 'New', last_name: 'Name', current_password: 'wrong' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not update the name' do
        original = @teacher.first_name
        patch api_v1_profile_url,
              params: { first_name: 'New', last_name: 'Name', current_password: 'wrong' }
        expect(@teacher.reload.first_name).to eq(original)
      end
    end

    describe 'when first name is blank' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns a validation error' do
        patch api_v1_profile_url,
              params: { first_name: '', last_name: 'Name', current_password: 'password123' }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_profile_url,
              params: { first_name: 'New', last_name: 'Name', current_password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
