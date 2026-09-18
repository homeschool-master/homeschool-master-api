# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::CalendarEvents', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def json_data
    JSON.parse(response.body)['data']
  end

  def event_times(day:, from: 9, to: 10)
    { start_time: Time.utc(2026, 9, day, from, 0, 0), end_time: Time.utc(2026, 9, day, to, 0, 0) }
  end

  let(:week) { { start_date: '2026-09-14', end_date: '2026-09-20' } }

  describe 'GET /api/v1/calendar_events' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns success' do
        get api_v1_calendar_events_url, params: week
        expect(response).to have_http_status(:ok)
      end

      it "returns the teacher's events in the range" do
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Math', **event_times(day: 15))
        get api_v1_calendar_events_url, params: week
        expect(json_data.map { |e| e['title'] }).to eq(['Math'])
      end

      it "excludes other teachers' events" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        FactoryBot.create(:calendar_event, teacher: other, title: 'NotMine', **event_times(day: 15))
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Mine', **event_times(day: 15))
        get api_v1_calendar_events_url, params: week
        expect(json_data.map { |e| e['title'] }).to eq(['Mine'])
      end

      it 'excludes events outside the range' do
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'InRange', **event_times(day: 15))
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'OutOfRange', **event_times(day: 30))
        get api_v1_calendar_events_url, params: week
        expect(json_data.map { |e| e['title'] }).to eq(['InRange'])
      end

      it 'includes an event later on the end date' do
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Evening',
                                           **event_times(day: 20, from: 20, to: 21))
        get api_v1_calendar_events_url, params: week
        expect(json_data.map { |e| e['title'] }).to eq(['Evening'])
      end

      it 'orders events by start time' do
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Later', **event_times(day: 17))
        FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Earlier', **event_times(day: 15))
        get api_v1_calendar_events_url, params: week
        expect(json_data.map { |e| e['title'] }).to eq(%w[Earlier Later])
      end

      it 'requires start_date' do
        get api_v1_calendar_events_url, params: { end_date: '2026-09-20' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'requires end_date' do
        get api_v1_calendar_events_url, params: { start_date: '2026-09-14' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects an unparseable date' do
        get api_v1_calendar_events_url, params: { start_date: 'not-a-date', end_date: '2026-09-20' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'filters by student_id' do
        student = FactoryBot.create(:student, teacher: @teacher)
        other_student = FactoryBot.create(:student, teacher: @teacher, first_name: 'Noah')
        mine = FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Mine', **event_times(day: 15))
        theirs = FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Theirs', **event_times(day: 16))
        FactoryBot.create(:event_attendee, calendar_event: mine, student: student)
        FactoryBot.create(:event_attendee, calendar_event: theirs, student: other_student)
        get api_v1_calendar_events_url, params: week.merge(student_id: student.id)
        expect(json_data.map { |e| e['title'] }).to eq(['Mine'])
      end

      it 'includes the attendee ids on each event' do
        student = FactoryBot.create(:student, teacher: @teacher, first_name: 'Emma')
        event = FactoryBot.create(:calendar_event, teacher: @teacher, **event_times(day: 15))
        FactoryBot.create(:event_attendee, calendar_event: event, student: student)
        get api_v1_calendar_events_url, params: week
        expect(json_data.first['attendee_ids']).to eq([student.id])
      end

      it 'does not nest student records on the events' do
        student = FactoryBot.create(:student, teacher: @teacher, first_name: 'Emma')
        event = FactoryBot.create(:calendar_event, teacher: @teacher, **event_times(day: 15))
        FactoryBot.create(:event_attendee, calendar_event: event, student: student)
        get api_v1_calendar_events_url, params: week
        expect(json_data.first).not_to have_key('attendees')
        expect(response.body).not_to include('Emma')
      end
    end

    context 'when a bare date names a local day' do
      # 2026-09-17T04:00:00Z through 2026-09-18T03:59:59Z is exactly the
      # teacher's local September 17 in Eastern, which is UTC-4 on that date.
      def create_full_local_day(teacher)
        FactoryBot.create(:calendar_event, teacher: teacher, title: 'LocalDay',
                                           start_time: Time.utc(2026, 9, 17, 4, 0, 0),
                                           end_time: Time.utc(2026, 9, 18, 3, 59, 59))
      end

      def titles
        JSON.parse(response.body)['data'].map { |e| e['title'] }
      end

      context 'with an Eastern teacher' do
        before do
          @teacher = FactoryBot.create(:teacher, time_zone: 'America/New_York')
          sign_in(@teacher)
          create_full_local_day(@teacher)
        end

        it 'returns the event on its own local day' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-17', end_date: '2026-09-17' }
          expect(titles).to eq(['LocalDay'])
        end

        it 'does not leak the event into the next local day' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-18', end_date: '2026-09-18' }
          expect(titles).to be_empty
        end

        it 'does not leak the event into the previous local day' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-16', end_date: '2026-09-16' }
          expect(titles).to be_empty
        end

        it 'keeps an evening event on its local day rather than the next UTC day' do
          FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Evening',
                                             start_time: Time.utc(2026, 9, 18, 1, 0, 0),
                                             end_time: Time.utc(2026, 9, 18, 2, 0, 0))
          get api_v1_calendar_events_url, params: { start_date: '2026-09-17', end_date: '2026-09-17' }
          expect(titles).to include('Evening')
        end

        it 'does not return that evening event on the following local day' do
          FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Evening',
                                             start_time: Time.utc(2026, 9, 18, 1, 0, 0),
                                             end_time: Time.utc(2026, 9, 18, 2, 0, 0))
          get api_v1_calendar_events_url, params: { start_date: '2026-09-18', end_date: '2026-09-18' }
          expect(titles).not_to include('Evening')
        end
      end

      context 'with a teacher who has no stored zone' do
        before do
          @teacher = FactoryBot.create(:teacher, time_zone: nil)
          sign_in(@teacher)
          create_full_local_day(@teacher)
        end

        it 'falls back to Eastern and returns the event on the 17th' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-17', end_date: '2026-09-17' }
          expect(titles).to eq(['LocalDay'])
        end

        it 'falls back to Eastern and excludes it on the 18th' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-18', end_date: '2026-09-18' }
          expect(titles).to be_empty
        end
      end

      # 2026-09-17T20:00:00Z is the afternoon of the 17th in Eastern and the
      # early morning of the 18th in Tokyo, so the same bare date resolves to a
      # window that includes it for one teacher and not the other.
      context 'when two teachers in different zones send the same bare date' do
        def create_afternoon_event(teacher)
          FactoryBot.create(:calendar_event, teacher: teacher, title: 'Afternoon',
                                             start_time: Time.utc(2026, 9, 17, 20, 0, 0),
                                             end_time: Time.utc(2026, 9, 17, 21, 0, 0))
        end

        it 'returns it on the 17th for the Eastern teacher' do
          teacher = FactoryBot.create(:teacher, time_zone: 'America/New_York')
          create_afternoon_event(teacher)
          sign_in(teacher)
          get api_v1_calendar_events_url, params: { start_date: '2026-09-17', end_date: '2026-09-17' }
          expect(titles).to eq(['Afternoon'])
        end

        it 'does not return it on the 17th for the Tokyo teacher' do
          teacher = FactoryBot.create(:teacher, email: 'tokyo@example.com', time_zone: 'Asia/Tokyo')
          create_afternoon_event(teacher)
          sign_in(teacher)
          get api_v1_calendar_events_url, params: { start_date: '2026-09-17', end_date: '2026-09-17' }
          expect(titles).to be_empty
        end

        it 'returns it on the 18th for the Tokyo teacher' do
          teacher = FactoryBot.create(:teacher, email: 'tokyo@example.com', time_zone: 'Asia/Tokyo')
          create_afternoon_event(teacher)
          sign_in(teacher)
          get api_v1_calendar_events_url, params: { start_date: '2026-09-18', end_date: '2026-09-18' }
          expect(titles).to eq(['Afternoon'])
        end

        it 'does not return it on the 18th for the Eastern teacher' do
          teacher = FactoryBot.create(:teacher, time_zone: 'America/New_York')
          create_afternoon_event(teacher)
          sign_in(teacher)
          get api_v1_calendar_events_url, params: { start_date: '2026-09-18', end_date: '2026-09-18' }
          expect(titles).to be_empty
        end
      end

      context 'with a value that already carries a time' do
        before do
          @teacher = FactoryBot.create(:teacher, time_zone: 'America/New_York')
          sign_in(@teacher)
          create_full_local_day(@teacher)
        end

        it 'honors an explicit offset as sent' do
          get api_v1_calendar_events_url, params: {
            start_date: '2026-09-17T00:00:00-04:00', end_date: '2026-09-17T23:59:59-04:00'
          }
          expect(titles).to eq(['LocalDay'])
        end

        it 'does not widen a value that carries a time' do
          # 00:00 through 01:00 UTC on the 17th ends before the event starts at
          # 04:00Z, so an unwidened window returns nothing.
          get api_v1_calendar_events_url, params: {
            start_date: '2026-09-17T00:00:00Z', end_date: '2026-09-17T01:00:00Z'
          }
          expect(titles).to be_empty
        end

        it 'does not reinterpret an explicit offset in the teacher zone' do
          # A UTC+09:00 window for the 17th ends at 2026-09-17T14:59:59Z. An
          # afternoon event at 20:00Z falls outside it, but inside the Eastern
          # local 17th, so a non empty result would mean the offset was ignored.
          FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Afternoon',
                                             start_time: Time.utc(2026, 9, 17, 20, 0, 0),
                                             end_time: Time.utc(2026, 9, 17, 21, 0, 0))
          get api_v1_calendar_events_url, params: {
            start_date: '2026-09-17T00:00:00+09:00', end_date: '2026-09-17T23:59:59+09:00'
          }
          expect(titles).not_to include('Afternoon')
        end
      end

      context 'with a genuine multi day event' do
        before do
          @teacher = FactoryBot.create(:teacher, time_zone: 'America/New_York')
          sign_in(@teacher)
          FactoryBot.create(:calendar_event, teacher: @teacher, title: 'Convention',
                                             start_time: Time.utc(2026, 9, 17, 14, 0, 0),
                                             end_time: Time.utc(2026, 9, 19, 21, 0, 0))
        end

        it 'appears on the first local day it spans' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-17', end_date: '2026-09-17' }
          expect(titles).to eq(['Convention'])
        end

        it 'appears on the middle local day it spans' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-18', end_date: '2026-09-18' }
          expect(titles).to eq(['Convention'])
        end

        it 'appears on the last local day it spans' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-19', end_date: '2026-09-19' }
          expect(titles).to eq(['Convention'])
        end

        it 'does not appear on the day after it ends' do
          get api_v1_calendar_events_url, params: { start_date: '2026-09-20', end_date: '2026-09-20' }
          expect(titles).to be_empty
        end
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_calendar_events_url, params: week
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/calendar_events/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @event = FactoryBot.create(:calendar_event, teacher: @teacher)
        sign_in(@teacher)
      end

      it 'returns the event' do
        get api_v1_calendar_event_url(@event)
        expect(response).to have_http_status(:ok)
        expect(json_data['id']).to eq(@event.id)
      end

      it 'returns the event payload fields' do
        get api_v1_calendar_event_url(@event)
        expect(json_data['notes']).to eq('Chapter 4 review')
        expect(json_data['location']).to eq('Kitchen table')
        expect(json_data['all_day']).to be(false)
        expect(json_data['created_time_zone']).to eq('America/New_York')
      end

      it 'returns not found when the event does not exist' do
        get api_v1_calendar_event_url('00000000-0000-0000-0000-000000000000')
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for another teacher's event" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        get api_v1_calendar_event_url(FactoryBot.create(:calendar_event, teacher: other))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_calendar_event_url(FactoryBot.create(:calendar_event))
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/calendar_events' do
    let(:valid_params) do
      {
        title: 'Math Lesson',
        notes: 'Chapter 4 review',
        location: 'Kitchen table',
        start_time: '2026-09-15T14:00:00Z',
        end_time: '2026-09-15T15:00:00Z',
        all_day: false
      }
    end

    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns created' do
        post api_v1_calendar_events_url, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'creates the event for the teacher' do
        expect do
          post api_v1_calendar_events_url, params: valid_params
        end.to change(@teacher.calendar_events, :count).by(1)
      end

      it 'returns the created payload' do
        post api_v1_calendar_events_url, params: valid_params
        expect(json_data['title']).to eq('Math Lesson')
        expect(json_data['teacher_id']).to eq(@teacher.id)
        expect(json_data['attendee_ids']).to eq([])
      end

      it 'attaches the submitted attendees' do
        emma = FactoryBot.create(:student, teacher: @teacher, first_name: 'Emma')
        noah = FactoryBot.create(:student, teacher: @teacher, first_name: 'Noah')
        post api_v1_calendar_events_url, params: valid_params.merge(student_ids: [emma.id, noah.id])
        expect(json_data['attendee_ids']).to contain_exactly(emma.id, noah.id)
      end

      it 'creates the attendee rows' do
        student = FactoryBot.create(:student, teacher: @teacher)
        expect do
          post api_v1_calendar_events_url, params: valid_params.merge(student_ids: [student.id])
        end.to change(EventAttendee, :count).by(1)
      end

      it 'rejects a student id belonging to another teacher' do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_student = FactoryBot.create(:student, teacher: other)
        post api_v1_calendar_events_url, params: valid_params.merge(student_ids: [other_student.id])
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'creates nothing when one attendee belongs to another teacher' do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        mine = FactoryBot.create(:student, teacher: @teacher)
        theirs = FactoryBot.create(:student, teacher: other)
        expect do
          post api_v1_calendar_events_url, params: valid_params.merge(student_ids: [mine.id, theirs.id])
        end.not_to change(CalendarEvent, :count)
      end

      it 'rejects an unknown student id' do
        post api_v1_calendar_events_url,
             params: valid_params.merge(student_ids: ['00000000-0000-0000-0000-000000000000'])
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects a missing title' do
        post api_v1_calendar_events_url, params: valid_params.merge(title: '')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects an end time before the start time' do
        post api_v1_calendar_events_url, params: valid_params.merge(end_time: '2026-09-15T13:00:00Z')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects a missing start time' do
        post api_v1_calendar_events_url, params: valid_params.except(:start_time)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'stores the submitted times in UTC without conversion' do
        post api_v1_calendar_events_url, params: valid_params
        event = CalendarEvent.find(json_data['id'])
        expect(event.start_time).to eq(Time.utc(2026, 9, 15, 14, 0, 0))
        expect(event.end_time).to eq(Time.utc(2026, 9, 15, 15, 0, 0))
      end

      it 'stores an all day event at the submitted day bounds' do
        post api_v1_calendar_events_url, params: valid_params.merge(
          all_day: true,
          start_time: '2026-09-15T00:00:00Z',
          end_time: '2026-09-15T23:59:59Z'
        )
        event = CalendarEvent.find(json_data['id'])
        expect(event.all_day).to be(true)
        expect(event.start_time).to eq(Time.utc(2026, 9, 15, 0, 0, 0))
        expect(event.end_time).to eq(Time.utc(2026, 9, 15, 23, 59, 59))
      end

      it 'ignores an injected teacher_id' do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        post api_v1_calendar_events_url, params: valid_params.merge(teacher_id: other.id)
        expect(json_data['teacher_id']).to eq(@teacher.id)
      end

      it 'records the client supplied created_time_zone' do
        post api_v1_calendar_events_url, params: valid_params.merge(created_time_zone: 'Europe/Lisbon')
        expect(json_data['created_time_zone']).to eq('Europe/Lisbon')
      end

      it "falls back to the teacher's zone when the client sends none" do
        @teacher.update!(time_zone: 'Asia/Tokyo')
        post api_v1_calendar_events_url, params: valid_params
        expect(json_data['created_time_zone']).to eq('Asia/Tokyo')
      end

      it 'falls back to the default when the teacher has no zone' do
        post api_v1_calendar_events_url, params: valid_params
        expect(json_data['created_time_zone']).to eq('America/New_York')
      end

      it 'rejects an unrecognized created_time_zone' do
        post api_v1_calendar_events_url, params: valid_params.merge(created_time_zone: 'Mars/Olympus_Mons')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'creates nothing when the created_time_zone is unrecognized' do
        expect do
          post api_v1_calendar_events_url, params: valid_params.merge(created_time_zone: 'Mars/Olympus_Mons')
        end.not_to change(CalendarEvent, :count)
      end

      it 'stores the timestamps in UTC regardless of the created_time_zone' do
        post api_v1_calendar_events_url, params: valid_params.merge(created_time_zone: 'Asia/Tokyo')
        event = CalendarEvent.find(json_data['id'])
        expect(event.start_time).to eq(Time.utc(2026, 9, 15, 14, 0, 0))
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post api_v1_calendar_events_url, params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/calendar_events/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @event = FactoryBot.create(:calendar_event, teacher: @teacher)
        @emma = FactoryBot.create(:student, teacher: @teacher, first_name: 'Emma')
        @noah = FactoryBot.create(:student, teacher: @teacher, first_name: 'Noah')
        FactoryBot.create(:event_attendee, calendar_event: @event, student: @emma)
        sign_in(@teacher)
      end

      it 'updates the event' do
        patch api_v1_calendar_event_url(@event), params: { title: 'Science Lesson', notes: 'Volcano' }
        expect(response).to have_http_status(:ok)
        @event.reload
        expect(@event.title).to eq('Science Lesson')
        expect(@event.notes).to eq('Volcano')
      end

      it 'replaces the attendee set with the submitted array' do
        patch api_v1_calendar_event_url(@event), params: { student_ids: [@noah.id] }
        expect(@event.reload.students).to eq([@noah])
      end

      it 'returns the replaced attendee ids in the payload' do
        patch api_v1_calendar_event_url(@event), params: { student_ids: [@noah.id] }
        expect(json_data['attendee_ids']).to eq([@noah.id])
      end

      it 'clears the attendees when sent an empty array' do
        patch api_v1_calendar_event_url(@event), params: { student_ids: [] }, as: :json
        expect(@event.reload.students).to be_empty
      end

      it 'leaves the attendees alone when no array is submitted' do
        patch api_v1_calendar_event_url(@event), params: { title: 'Renamed' }
        expect(@event.reload.students).to eq([@emma])
      end

      it 'rejects a student id belonging to another teacher' do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_student = FactoryBot.create(:student, teacher: other)
        patch api_v1_calendar_event_url(@event), params: { student_ids: [other_student.id] }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'keeps the existing attendees when the submitted set is rejected' do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_student = FactoryBot.create(:student, teacher: other)
        patch api_v1_calendar_event_url(@event), params: { student_ids: [@noah.id, other_student.id] }
        expect(@event.reload.students).to eq([@emma])
      end

      it 'rejects a blank title' do
        patch api_v1_calendar_event_url(@event), params: { title: '' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not let the client rewrite created_time_zone' do
        @event.update!(created_time_zone: 'Europe/Lisbon')
        patch api_v1_calendar_event_url(@event), params: { created_time_zone: 'Asia/Tokyo' }
        expect(@event.reload.created_time_zone).to eq('Europe/Lisbon')
      end

      it 'rejects an end time before the start time' do
        patch api_v1_calendar_event_url(@event), params: { end_time: '2026-09-15T13:00:00Z' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns not found for another teacher's event" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_event = FactoryBot.create(:calendar_event, teacher: other)
        patch api_v1_calendar_event_url(other_event), params: { title: 'Hijacked' }
        expect(response).to have_http_status(:not_found)
        expect(other_event.reload.title).to eq('Math Lesson')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_calendar_event_url(FactoryBot.create(:calendar_event)), params: { title: 'Nope' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/calendar_events/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @event = FactoryBot.create(:calendar_event, teacher: @teacher)
        @student = FactoryBot.create(:student, teacher: @teacher)
        FactoryBot.create(:event_attendee, calendar_event: @event, student: @student)
        sign_in(@teacher)
      end

      it 'returns no content' do
        delete api_v1_calendar_event_url(@event)
        expect(response).to have_http_status(:no_content)
      end

      it 'removes the event' do
        delete api_v1_calendar_event_url(@event)
        expect(CalendarEvent.find_by(id: @event.id)).to be_nil
      end

      it 'removes the attendee rows' do
        expect { delete api_v1_calendar_event_url(@event) }.to change(EventAttendee, :count).by(-1)
      end

      it 'leaves the students themselves alone' do
        delete api_v1_calendar_event_url(@event)
        expect(Student.find_by(id: @student.id)).to be_present
      end

      it "returns not found for another teacher's event" do
        other = FactoryBot.create(:teacher, email: 'other@example.com')
        other_event = FactoryBot.create(:calendar_event, teacher: other)
        delete api_v1_calendar_event_url(other_event)
        expect(response).to have_http_status(:not_found)
        expect(CalendarEvent.find_by(id: other_event.id)).to be_present
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        delete api_v1_calendar_event_url(FactoryBot.create(:calendar_event))
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
