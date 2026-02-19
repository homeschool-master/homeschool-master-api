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

          expect(json_response['error']['message']).to eq('Invalid email or password')
        end
      end

      context 'when the email does not exist' do
        it 'should return an unathorized response' do
          post api_v1_auth_login_url, params: { email: 'email@doesnotexist.com', password: 'WrongPassword123' }
          json_response = JSON.parse(response.body)

          expect(json_response['error']['message']).to eq('Invalid email or password')
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
end
