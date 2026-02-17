# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Authentication', type: :request do
  context 'POST /api/v1/auth/login' do
    describe 'when the login is successful' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
        @json_response = JSON.parse(response.body)
      end
      it 'should return a successfull response' do
        expect(response).to have_http_status(:success)
      end
      it 'should generate an access token' do
        decoded = JwtService.decode(@json_response['access_token'])

        expect(decoded).to be_present
        expect(decoded[:teacher_id]).to eq(@teacher.id)
      end
      it 'should generate a refresh token and store it in the db' do
        decoded = JwtService.decode(@json_response['refresh_token'])

        expect(decoded).to be_present
        expect(decoded[:teacher_id]).to eq(@teacher.id)
        expect(@teacher.refresh_tokens.last.token).to eq(@json_response['refresh_token'])
      end
    end

    describe 'when the login is unsuccessfull' do
      before do
        @teacher = FactoryBot.create(:teacher)
      end

      context 'when the passord is wrong' do
        it 'should return an unathorized response' do
          post api_v1_auth_login_url, params: { email: @teacher.email, password: 'WrongPassword123' }
          json_response = JSON.parse(response.body)

          expect(json_response['error']).to eq('unauthorized')
        end
      end

      context 'when the email does not exist' do
        it 'should return an unathorized response' do
          post api_v1_auth_login_url, params: { email: 'email@doesnotexist.com', password: 'WrongPassword123' }
          json_response = JSON.parse(response.body)

          expect(json_response['error']).to eq('unauthorized')
        end
      end
    end
  end
end
