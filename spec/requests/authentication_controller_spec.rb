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

      it 'should return a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'should set the access token cookie' do
        expect(response.cookies['access_token']).to be_present
      end

      it 'sets the refresh token cookie' do
        expect(response.cookies['refresh_token']).to be_present
      end

      it 'returns user data in the response body' do
        expect(@json_response['data']).to be_present
        expect(@json_response['data']['email']).to eq(@teacher.email)
      end

      it 'does not return tokens in the response body' do
        expect(@json_response).not_to have_key('access_token')
        expect(@json_response).not_to have_key('refresh_token')
      end

      it 'stores the refresh token in the database' do
        expect(@teacher.refresh_tokens.count).to eq(1)
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

          expect(response).to have_http_status(:unauthorized)
          expect(json_response['error']['message']).to eq('Invalid email or password')
        end
      end

      context 'when the email does not exist' do
        it 'should return an unathorized response' do
          post api_v1_auth_login_url, params: { email: 'email@doesnotexist.com', password: 'WrongPassword123' }
          json_response = JSON.parse(response.body)

          expect(response).to have_http_status(:unauthorized)
          expect(json_response['error']['message']).to eq('Invalid email or password')
        end
      end

      context 'when the account is deactivated' do
        it 'returns an unauthorized response' do
          @teacher.update!(is_active: false)
          post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  context 'POST /api/v1/auth/register' do
    describe 'when registration is successful' do
      let(:valid_params) do
        {
          first_name: 'Robert',
          last_name: 'Masters',
          email: 'robert@example.com',
          password: 'password123'
        }
      end

      it 'should return a created response' do
        post api_v1_auth_register_url, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'should create a new teacher' do
        expect do
          post api_v1_auth_register_url, params: valid_params
        end.to change(Teacher, :count).by(1)
      end

      it 'should return the teacher data' do
        post api_v1_auth_register_url, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response['data']['email']).to eq('robert@example.com')
        expect(json_response['data']['first_name']).to eq('Robert')
        expect(json_response['data']['last_name']).to eq('Masters')
      end

      it 'should not return the password' do
        post api_v1_auth_register_url, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response['data']).not_to have_key('password')
        expect(json_response['data']).not_to have_key('password_digest')
      end
    end

    describe 'when registration fails' do
      context 'when email already exists' do
        before do
          FactoryBot.create(:teacher, email: 'existing@example.com')
        end

        it 'should return a validation error' do
          post api_v1_auth_register_url, params: {
            first_name: 'Robert',
            last_name: 'Masters',
            email: 'existing@example.com',
            password: 'password123'
          }
          json_response = JSON.parse(response.body)

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['error']['details']['email']).to include('has already been taken')
        end
      end

      context 'when required fields are missing' do
        it 'should return validation errors for missing first name' do
          post api_v1_auth_register_url, params: {
            last_name: 'Masters',
            email: 'test@example.com',
            password: 'password123'
          }
          json_response = JSON.parse(response.body)

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['error']['details']['first_name']).to include("can't be blank")
        end
      end

      context 'when password is too short' do
        it 'should return a validation error' do
          post api_v1_auth_register_url, params: {
            first_name: 'Robert',
            last_name: 'Masters',
            email: 'test@example.com',
            password: 'short'
          }
          json_response = JSON.parse(response.body)

          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['error']['details']['password']).to include('is too short (minimum is 8 characters)')
        end
      end
    end
  end

  context 'GET /api/v1/auth/me' do
    describe 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
        get api_v1_auth_me_url
        @json_response = JSON.parse(response.body)
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the current user data' do
        expect(@json_response['data']['email']).to eq(@teacher.email)
        expect(@json_response['data']['first_name']).to eq(@teacher.first_name)
      end
    end

    describe 'when not authenticated' do
      it 'returns an unauthorized response' do
        get api_v1_auth_me_url
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  context 'POST /api/v1/auth/refresh' do
    describe 'when refresh is successful' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
        post api_v1_auth_refresh_url
        @json_response = JSON.parse(response.body)
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets a new access token cookie' do
        expect(response.cookies['access_token']).to be_present
      end
    end

    describe 'when refresh fails' do
      context 'when no cookie is present' do
        it 'returns an unauthorized response' do
          post api_v1_auth_refresh_url
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when refresh token is revoked' do
        before do
          @teacher = FactoryBot.create(:teacher)
          post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
          RefreshToken.last.update(revoked_at: Time.current)
        end

        it 'returns an unauthorized response' do
          post api_v1_auth_refresh_url
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  context 'POST /api/v1/auth/logout' do
    describe 'when logout is successful' do
      before do
        @teacher = FactoryBot.create(:teacher)
        post api_v1_auth_login_url, params: { email: @teacher.email, password: 'password123' }
      end

      it 'returns no content status' do
        post api_v1_auth_logout_url
        expect(response).to have_http_status(:no_content)
      end

      it 'revokes the refresh token' do
        post api_v1_auth_logout_url
        expect(RefreshToken.last.revoked_at).to be_present
      end

      it 'prevents the refresh token from being used again' do
        post api_v1_auth_logout_url
        post api_v1_auth_refresh_url
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'when no cookie is present' do
      it 'still returns no content' do
        post api_v1_auth_logout_url
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
