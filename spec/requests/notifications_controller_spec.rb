# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Notifications', type: :request do
  context 'PATCH /api/v1/notifications' do
    describe 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns success' do
        patch api_v1_notifications_url, params: {
          notify_account_updates: false,
          notify_product_updates: false,
          notify_homeschool_resources: false
        }
        expect(response).to have_http_status(:ok)
      end

      it 'updates the preferences' do
        patch api_v1_notifications_url, params: {
          notify_account_updates: false,
          notify_product_updates: true,
          notify_homeschool_resources: false
        }
        @teacher.reload
        expect(@teacher.notify_account_updates).to be(false)
        expect(@teacher.notify_product_updates).to be(true)
        expect(@teacher.notify_homeschool_resources).to be(false)
      end

      it 'returns the updated user payload' do
        patch api_v1_notifications_url, params: {
          notify_account_updates: false,
          notify_product_updates: true,
          notify_homeschool_resources: true
        }
        json_response = JSON.parse(response.body)
        expect(json_response['data']['notify_account_updates']).to be(false)
        expect(json_response['data']['notify_product_updates']).to be(true)
        expect(json_response['data']['notify_homeschool_resources']).to be(true)
      end

      it 'allows partial updates without disturbing untouched prefs' do
        patch api_v1_notifications_url, params: { notify_account_updates: false }
        @teacher.reload
        expect(@teacher.notify_account_updates).to be(false)
        expect(@teacher.notify_product_updates).to be(true)
        expect(@teacher.notify_homeschool_resources).to be(true)
      end
    end

    describe 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_notifications_url, params: { notify_account_updates: false }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
