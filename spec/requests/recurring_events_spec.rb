# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::CalendarEvents recurrence', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def json_data
    JSON.parse(response.body)['data']
  end

  # September 2026 opens on a Tuesday, so Tuesdays are 1, 8, 15, 22 and 29.
  let(:september) { { start_date: '2026-09-01', end_date: '2026-09-30' } }

  before do
    @teacher = FactoryBot.create(:teacher)
    sign_in(@teacher)
  end

  def weekly_series(weekdays: [2], until_date: nil)
    event = FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Latin',
                                               start_time: Time.utc(2026, 9, 1, 14, 0, 0),
                                               end_time: Time.utc(2026, 9, 1, 15, 0, 0))
    FactoryBot.create(:recurrence, recurrable: event, frequency: 'weekly',
                                   weekdays: weekdays, until_date: until_date)
    event.reload
  end

  describe 'GET /api/v1/calendar_events' do
    it 'expands a series into its occurrences' do
      weekly_series

      get api_v1_calendar_events_url, params: september

      expect(json_data.map { |e| e['occurrence_date'] })
        .to eq(%w[2026-09-01 2026-09-08 2026-09-15 2026-09-22 2026-09-29])
    end

    # An occurrence has no row, so it is named by its series and its date.
    it 'names each occurrence by its series and date' do
      event = weekly_series

      get api_v1_calendar_events_url, params: september

      expect(json_data.first['id']).to eq("#{event.id}:2026-09-01")
      expect(json_data.first['series_id']).to eq(event.id)
    end

    # Everything created before this feature has to keep working untouched.
    it 'returns an ordinary event unchanged beside a series' do
      FactoryBot.create(:calendar_event, teacher: @teacher, title: 'One off',
                                         start_time: Time.utc(2026, 9, 3, 14, 0, 0),
                                         end_time: Time.utc(2026, 9, 3, 15, 0, 0))
      weekly_series

      get api_v1_calendar_events_url, params: september

      single = json_data.find { |e| e['title'] == 'One off' }
      expect(single['id']).not_to include(':')
      expect(single['series_id']).to be_nil
      expect(single['recurrence']).to be_nil
    end

    it 'orders occurrences and ordinary events together by time' do
      FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Wednesday',
                                         start_time: Time.utc(2026, 9, 2, 14, 0, 0),
                                         end_time: Time.utc(2026, 9, 2, 15, 0, 0))
      weekly_series

      get api_v1_calendar_events_url, params: september

      expect(json_data.first(2).map { |e| e['title'] }).to eq(%w[Latin Wednesday])
    end

    it 'stops at the end of the series' do
      weekly_series(until_date: Date.new(2026, 9, 15))

      get api_v1_calendar_events_url, params: september

      expect(json_data.map { |e| e['occurrence_date'] }).to eq(%w[2026-09-01 2026-09-08 2026-09-15])
    end

    it 'sends the rule on every occurrence' do
      weekly_series(weekdays: [2, 4])

      get api_v1_calendar_events_url, params: september

      expect(json_data.first['recurrence']).to include('frequency' => 'weekly', 'weekdays' => [2, 4])
    end
  end

  describe 'POST /api/v1/calendar_events' do
    let(:valid_params) do
      { title: 'Latin', start_time: '2026-09-01T14:00:00Z', end_time: '2026-09-01T15:00:00Z' }
    end

    it 'creates a series' do
      post api_v1_calendar_events_url,
           params: valid_params.merge(recurrence: { frequency: 'weekly', weekdays: [2] }), as: :json

      expect(response).to have_http_status(:created)
      expect(json_data['recurrence']).to include('frequency' => 'weekly')
    end

    it 'creates an ordinary event when no rule is sent' do
      post api_v1_calendar_events_url, params: valid_params, as: :json

      expect(json_data['recurrence']).to be_nil
    end

    it 'refuses a weekly rule naming no days, and creates nothing' do
      expect do
        post api_v1_calendar_events_url,
             params: valid_params.merge(recurrence: { frequency: 'weekly', weekdays: [] }), as: :json
      end.not_to change(CalendarEvent, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a frequency it does not know' do
      post api_v1_calendar_events_url,
           params: valid_params.merge(recurrence: { frequency: 'fortnightly' }), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /api/v1/calendar_events/:id' do
    it 'returns one occurrence at its own times' do
      event = weekly_series

      get api_v1_calendar_event_url("#{event.id}:2026-09-15")

      expect(json_data['occurrence_date']).to eq('2026-09-15')
      expect(json_data['start_time']).to eq('2026-09-15T14:00:00.000Z')
    end

    it 'still returns an ordinary event by its bare id' do
      event = FactoryBot.create(:calendar_event, teacher: @teacher)

      get api_v1_calendar_event_url(event.id)

      expect(json_data['id']).to eq(event.id)
      expect(json_data['occurrence_date']).to be_nil
    end

    it 'does not return another teacher\'s series' do
      other = FactoryBot.create(:teacher, email: 'other@test.com')
      event = FactoryBot.create(:calendar_event, teacher: other)
      FactoryBot.create(:recurrence, recurrable: event)

      get api_v1_calendar_event_url("#{event.id}:2026-09-15")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH with scope this' do
    it 'detaches the occurrence and leaves the rest alone' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Latin, moved', scope: 'this' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_data['title']).to eq('Latin, moved')
      expect(json_data['series_id']).to be_nil
    end

    it 'shows the edited occurrence once, in place of the original' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Latin, moved', scope: 'this' }, as: :json
      get api_v1_calendar_events_url, params: september

      titles = json_data.map { |e| e['title'] }
      expect(titles).to eq(['Latin', 'Latin', 'Latin, moved', 'Latin', 'Latin'])
    end

    it 'copies the attendees of the series onto the detached occurrence' do
      event = weekly_series
      student = FactoryBot.create(:student, teacher: @teacher)
      event.students << student

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Latin, moved', scope: 'this' }, as: :json

      expect(json_data['attendee_ids']).to eq([student.id])
    end

    it 'leaves the series itself untouched' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Latin, moved', scope: 'this' }, as: :json

      expect(event.reload.title).to eq('Latin')
      expect(event.recurrence.until_date).to be_nil
    end
  end

  describe 'PATCH with scope this_and_future' do
    it 'splits the series, leaving the earlier occurrences as they were' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Greek', scope: 'this_and_future' }, as: :json
      get api_v1_calendar_events_url, params: september

      expect(json_data.map { |e| e['title'] }).to eq(%w[Latin Latin Greek Greek Greek])
    end

    it 'ends the original the day before the split' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Greek', scope: 'this_and_future' }, as: :json

      expect(event.reload.recurrence.until_date).to eq(Date.new(2026, 9, 14))
    end

    it 'gives the new series the same rule' do
      event = weekly_series(weekdays: [2, 4])

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Greek', scope: 'this_and_future' }, as: :json

      expect(json_data['recurrence']).to include('frequency' => 'weekly', 'weekdays' => [2, 4])
    end

    # Nothing survives in front of the first occurrence, so there is nothing
    # to split: the request means the same as editing all of it.
    it 'edits the whole series when the split is at the first occurrence' do
      event = weekly_series

      expect do
        patch api_v1_calendar_event_url("#{event.id}:2026-09-01"),
              params: { title: 'Greek', scope: 'this_and_future' }, as: :json
      end.not_to change(CalendarEvent, :count)

      expect(event.reload.title).to eq('Greek')
      expect(event.recurrence.until_date).to be_nil
    end
  end

  describe 'PATCH with scope all' do
    it 'moves every occurrence' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Greek', scope: 'all' }, as: :json
      get api_v1_calendar_events_url, params: september

      expect(json_data.map { |e| e['title'] }.uniq).to eq(['Greek'])
    end

    it 'can change the rule itself' do
      event = weekly_series

      patch api_v1_calendar_event_url(event.id),
            params: { recurrence: { frequency: 'weekly', weekdays: [2, 4] } }, as: :json
      get api_v1_calendar_events_url, params: september

      expect(json_data.length).to eq(9)
    end

    it 'can stop an event repeating at all' do
      event = weekly_series

      patch api_v1_calendar_event_url(event.id), params: { recurrence: nil }, as: :json
      get api_v1_calendar_events_url, params: september

      expect(json_data.length).to eq(1)
      expect(json_data.first['recurrence']).to be_nil
    end

    it 'defaults to all when no scope is sent' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Greek' }, as: :json

      expect(event.reload.title).to eq('Greek')
    end

    it 'refuses a scope it does not know' do
      event = weekly_series

      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Greek', scope: 'sideways' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.reload.title).to eq('Latin')
    end
  end

  describe 'DELETE' do
    it 'takes one occurrence out with scope this' do
      event = weekly_series

      delete api_v1_calendar_event_url("#{event.id}:2026-09-15"), params: { scope: 'this' }
      get api_v1_calendar_events_url, params: september

      expect(json_data.map { |e| e['occurrence_date'] })
        .to eq(%w[2026-09-01 2026-09-08 2026-09-22 2026-09-29])
    end

    it 'ends the series with scope this_and_future' do
      event = weekly_series

      delete api_v1_calendar_event_url("#{event.id}:2026-09-15"), params: { scope: 'this_and_future' }
      get api_v1_calendar_events_url, params: september

      expect(json_data.map { |e| e['occurrence_date'] }).to eq(%w[2026-09-01 2026-09-08])
      expect(event.reload.recurrence.until_date).to eq(Date.new(2026, 9, 14))
    end

    it 'removes the whole series with scope all' do
      event = weekly_series

      delete api_v1_calendar_event_url("#{event.id}:2026-09-15"), params: { scope: 'all' }

      expect(CalendarEvent.exists?(event.id)).to be(false)
      expect(Recurrence.count).to eq(0)
    end

    # Deleting from the first occurrence leaves nothing in front of it.
    it 'removes the series when the cut is at the first occurrence' do
      event = weekly_series

      delete api_v1_calendar_event_url("#{event.id}:2026-09-01"), params: { scope: 'this_and_future' }

      expect(CalendarEvent.exists?(event.id)).to be(false)
    end

    it 'takes an edited occurrence with the series it belonged to' do
      event = weekly_series
      patch api_v1_calendar_event_url("#{event.id}:2026-09-15"),
            params: { title: 'Latin, moved', scope: 'this' }, as: :json
      detached = json_data['id']

      delete api_v1_calendar_event_url(event.id), params: { scope: 'all' }

      expect(CalendarEvent.exists?(detached)).to be(false)
    end

    it 'still deletes an ordinary event' do
      event = FactoryBot.create(:calendar_event, teacher: @teacher)

      delete api_v1_calendar_event_url(event.id)

      expect(CalendarEvent.exists?(event.id)).to be(false)
    end
  end
end
