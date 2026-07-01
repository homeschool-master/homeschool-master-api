# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Onboarding', type: :request do
  context 'PATCH /api/v1/onboarding' do
    describe 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns success' do
        patch api_v1_onboarding_url
        expect(response).to have_http_status(:ok)
      end

      it 'marks onboarding as completed' do
        expect(@teacher.onboarding_completed).to be(false)
        patch api_v1_onboarding_url
        expect(@teacher.reload.onboarding_completed).to be(true)
      end

      it 'returns the updated user payload' do
        patch api_v1_onboarding_url
        json_response = JSON.parse(response.body)
        expect(json_response['data']['onboarding_completed']).to be(true)
      end

      it 'stays completed when called again' do
        patch api_v1_onboarding_url
        patch api_v1_onboarding_url
        expect(response).to have_http_status(:ok)
        expect(@teacher.reload.onboarding_completed).to be(true)
      end
    end

    describe 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_onboarding_url
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
