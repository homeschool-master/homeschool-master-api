# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth::Authentication', type: :request do
  context 'POST /api/v1/auth/login' do
    describe 'when the login is successful' do
      before do
        @teacher = FactoryBot.create(:teacher)
      end

      it 'should generate an access token' do
      end
      it 'should generate a refresh token and store it in the db' do
      end
    end

    describe 'when the login is unsuccessfull' do
      context 'when the passord is wrong' do
      end
      context 'when the email does not exist' do
      end
    end
  end
end
