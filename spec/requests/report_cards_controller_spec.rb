# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::ReportCards', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def body
    JSON.parse(response.body)
  end

  def data
    body['data']
  end

  before do
    @teacher = FactoryBot.create(:teacher)
    @student = FactoryBot.create(:student, teacher: @teacher)
    @math = FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
    sign_in(@teacher)
  end

  def work(earned:, possible: 100, title: 'Chapter 4', due: Date.new(2026, 9, 10))
    assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @math, title: title,
                                                points_possible: possible, due_date: due)
    FactoryBot.create(:assignment_grade, assignment: assignment, student: @student, points_earned: earned)
    assignment
  end

  def create_card(**overrides)
    post api_v1_report_cards_url, params: {
      student_id: @student.id, title: 'Autumn term',
      period_start: '2026-09-01', period_end: '2026-09-30'
    }.merge(overrides)
    data
  end

  describe 'POST /api/v1/report_cards' do
    it 'creates a draft' do
      work(earned: 90)
      card = create_card

      expect(response).to have_http_status(:created)
      expect(card['issued']).to be(false)
      expect(card['version']).to eq(1)
    end

    it 'computes a draft from current grades' do
      work(earned: 90)
      card = create_card

      expect(card['overall']['percentage'].to_f).to eq(90.0)
      expect(card['subjects'].first['subject_name']).to eq('Math')
    end

    it 'refuses a period that ends before it starts' do
      create_card(period_start: '2026-09-30', period_end: '2026-09-01')
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "refuses another teacher's student" do
      theirs = FactoryBot.create(:student, teacher: FactoryBot.create(:teacher))
      create_card(student_id: theirs.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']['details']).to have_key('student_id')
    end
  end

  describe 'POST /api/v1/report_cards/:id/issue' do
    it 'freezes the card' do
      work(earned: 90)
      card = create_card
      post issue_api_v1_report_card_url(card['id'])

      expect(response).to have_http_status(:ok)
      expect(data['issued']).to be(true)
      expect(data['captured']).to be(true)
    end

    it 'keeps saying what it said after a rescore' do
      assignment = work(earned: 90)
      card = create_card
      post issue_api_v1_report_card_url(card['id'])
      issued = data

      assignment.assignment_grades.first.update!(points_earned: 20)
      get api_v1_report_card_url(card['id'])

      expect(data['overall']['percentage']).to eq(issued['overall']['percentage'])
      expect(data['subjects']).to eq(issued['subjects'])
    end

    it 'refuses to issue twice' do
      card = create_card
      post issue_api_v1_report_card_url(card['id'])
      post issue_api_v1_report_card_url(card['id'])

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'versions' do
    before do
      work(earned: 90)
      @card = create_card
      post issue_api_v1_report_card_url(@card['id'])
    end

    it 'makes a new version when an issued card is edited' do
      patch api_v1_report_card_url(@card['id']), params: { title: 'Autumn term, corrected' }

      expect(response).to have_http_status(:ok)
      expect(data['version']).to eq(2)
      expect(data['id']).not_to eq(@card['id'])
      expect(data['group_id']).to eq(@card['group_id'])
    end

    it 'leaves the version that was handed over exactly as it was' do
      patch api_v1_report_card_url(@card['id']), params: { title: 'Autumn term, corrected' }

      get api_v1_report_card_url(@card['id'])
      expect(data['title']).to eq('Autumn term')
      expect(data['version']).to eq(1)
      expect(data['issued']).to be(true)
    end

    it 'carries the frozen figures into the new version rather than recomputing' do
      assignment = Assignment.find_by(title: 'Chapter 4')
      assignment.assignment_grades.first.update!(points_earned: 20)

      patch api_v1_report_card_url(@card['id']), params: { comments: 'Fixed a typo' }

      expect(data['overall']['percentage'].to_f).to eq(90.0)
      expect(data['captured']).to be(true)
    end

    it 'pulls the figures up to date only when refresh is asked for' do
      assignment = Assignment.find_by(title: 'Chapter 4')
      assignment.assignment_grades.first.update!(points_earned: 20)
      patch api_v1_report_card_url(@card['id']), params: { comments: 'Fixed a typo' }

      post refresh_api_v1_report_card_url(data['id'])

      expect(data['overall']['percentage'].to_f).to eq(20.0)
      expect(data['captured']).to be(false)
    end

    it 'numbers versions in sequence and lists them oldest first' do
      patch api_v1_report_card_url(@card['id']), params: { title: 'Second' }
      second = data
      post issue_api_v1_report_card_url(second['id'])
      patch api_v1_report_card_url(second['id']), params: { title: 'Third' }

      get versions_api_v1_report_card_url(@card['id'])
      expect(data.map { |v| v['version'] }).to eq([1, 2, 3])
      expect(data.map { |v| v['title'] }).to eq(['Autumn term', 'Second', 'Third'])
    end

    it 'marks only the highest version as the latest' do
      patch api_v1_report_card_url(@card['id']), params: { title: 'Second' }

      get versions_api_v1_report_card_url(@card['id'])
      expect(data.map { |v| v['latest_version'] }).to eq([false, true])
    end

    it 'lists one row per card rather than one per version' do
      patch api_v1_report_card_url(@card['id']), params: { title: 'Second' }

      get api_v1_report_cards_url
      expect(data.length).to eq(1)
      expect(data.first['version']).to eq(2)
    end
  end

  describe 'overrides' do
    it 'keeps the calculated grade beside the one the teacher issued' do
      work(earned: 85)
      card = create_card
      patch api_v1_report_card_url(card['id']), params: {
        overall_override_letter: 'A', overall_override_reason: 'Sustained effort all term',
        entries: [{ subject_id: @math.id, override_letter: 'A', comments: 'Real progress' }]
      }

      subject_line = data['subjects'].first
      expect(subject_line['letter']).to eq('B')
      expect(subject_line['override_letter']).to eq('A')
      expect(subject_line['effective_letter']).to eq('A')
      expect(subject_line['overridden']).to be(true)
      expect(data['overall']['letter']).to eq('B')
      expect(data['overall']['effective_letter']).to eq('A')
    end

    it 'survives issuing, with the calculated grade still there' do
      work(earned: 85)
      card = create_card
      patch api_v1_report_card_url(card['id']), params: {
        entries: [{ subject_id: @math.id, override_letter: 'A' }]
      }
      post issue_api_v1_report_card_url(card['id'])

      subject_line = data['subjects'].first
      expect(subject_line['letter']).to eq('B')
      expect(subject_line['override_letter']).to eq('A')
    end

    it 'takes an optional reason' do
      work(earned: 85)
      card = create_card
      patch api_v1_report_card_url(card['id']), params: {
        entries: [{ subject_id: @math.id, override_letter: 'A' }]
      }

      expect(response).to have_http_status(:ok)
      expect(data['subjects'].first['override_reason']).to be_nil
    end

    it 'refuses a letter that is not on the scale' do
      work(earned: 85)
      card = create_card
      patch api_v1_report_card_url(card['id']), params: { overall_override_letter: 'A+' }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/report_cards/:id' do
    it 'deletes a draft, since nothing was handed to anyone' do
      card = create_card
      delete api_v1_report_card_url(card['id'])

      expect(response).to have_http_status(:no_content)
      expect(ReportCard.find_by(id: card['id'])).to be_nil
    end

    it 'refuses to delete an issued card' do
      card = create_card
      post issue_api_v1_report_card_url(card['id'])
      delete api_v1_report_card_url(card['id'])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ReportCard.find_by(id: card['id'])).to be_present
    end
  end

  # A report card is the most private thing in the app: one child's grades,
  # named, for a period.
  describe 'cross teacher access' do
    before do
      @other = FactoryBot.create(:teacher)
      @theirs = FactoryBot.create(:report_card, teacher: @other,
                                                student: FactoryBot.create(:student, teacher: @other),
                                                title: 'Not yours')
    end

    it 'does not list another teacher\'s cards' do
      get api_v1_report_cards_url
      expect(data.map { |c| c['title'] }).not_to include('Not yours')
    end

    it 'refuses to show one' do
      get api_v1_report_card_url(@theirs)
      expect(response).to have_http_status(:not_found)
    end

    it 'refuses to edit one' do
      patch api_v1_report_card_url(@theirs), params: { title: 'Stolen' }

      expect(response).to have_http_status(:not_found)
      expect(@theirs.reload.title).to eq('Not yours')
    end

    it 'refuses to issue one' do
      post issue_api_v1_report_card_url(@theirs)

      expect(response).to have_http_status(:not_found)
      expect(@theirs.reload.issued_at).to be_nil
    end

    it 'refuses to delete one' do
      delete api_v1_report_card_url(@theirs)

      expect(response).to have_http_status(:not_found)
      expect(ReportCard.find_by(id: @theirs.id)).to be_present
    end

    it 'refuses to read its versions' do
      get versions_api_v1_report_card_url(@theirs)
      expect(response).to have_http_status(:not_found)
    end
  end
end

RSpec.describe 'Api::V1::ReportCards without a session', type: :request do
  it 'returns unauthorized' do
    get api_v1_report_cards_url
    expect(response).to have_http_status(:unauthorized)
  end
end
