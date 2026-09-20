# frozen_string_literal: true

module Api
  module V1
    class CalendarEventsController < BaseController
      include SeriesEditing
      include SubmittedStudents
      include CalendarSeries

      before_action :set_calendar_event, only: %i[show update destroy]

      # GET /api/v1/calendar_events?start_date=&end_date=&student_ids[]=
      def index
        range = parsed_range
        return render_missing_range if range.nil?

        render_success(feed(range).map { |entry| render_entry(entry) })
      end

      # GET /api/v1/calendar_events/:id
      #
      # A bare uuid for an ordinary event, or "<uuid>:<date>" for one
      # occurrence of a series: an occurrence has no row of its own, so it is
      # named by its series and the local date it falls on.
      def show
        render_success(CalendarEventSerializer.render(@calendar_event, occurrence: shown_occurrence))
      end

      # POST /api/v1/calendar_events
      def create
        attendee_ids = submitted_student_ids
        return render_unowned_students if attendee_ids && !students_owned?(attendee_ids)

        event = build_event_with_rule
        return if performed?

        save_with_attendees(event, attendee_ids)
        render_created(CalendarEventSerializer.render(event))
      end

      # PATCH /api/v1/calendar_events/:id
      #
      # A submitted attendee array replaces the existing set outright. On an
      # occurrence of a series, scope says how far the edit reaches: this
      # occurrence, this and future, or all of them.
      def update
        attendee_ids = submitted_student_ids
        return render_unowned_students if attendee_ids && !students_owned?(attendee_ids)
        return render_invalid_scope unless valid_scope?

        update_series_or_record(attendee_ids)
      end

      # DELETE /api/v1/calendar_events/:id
      # Hard delete: attendee rows go with it via the association and the
      # database cascade. scope reaches as far as it does on update.
      def destroy
        return render_invalid_scope unless valid_scope?

        destroy_series_or_record
        render_no_content
      end

      private

      # The event and its rule are validated together, so a bad rule rejects the
      # whole request rather than leaving an event behind that does not repeat.
      def build_event_with_rule
        event = current_teacher.calendar_events.build(create_params)
        rule = assign_rule(event)
        render_validation_errors(event) unless event.valid?
        render_validation_errors(rule) if !performed? && rule&.invalid?
        event
      end

      # Ordinary events and the occurrences of recurring ones, in one list.
      def feed(range)
        CalendarEventFeed.call(teacher: current_teacher, range: range,
                               student_ids: filter_student_ids)
      end

      def render_entry(entry)
        CalendarEventSerializer.render(entry.event, occurrence: entry.occurrence)
      end

      # student_ids[] is the array form, matching the name create and update
      # already use for the same idea. student_id stays as the one id
      # shorthand rather than becoming a second vocabulary for it.
      #
      # An id belonging to another teacher is not rejected here the way it is
      # on a write: the query is already scoped to this teacher's own events,
      # so such an id matches nothing, and no events of yours attended by
      # someone else's student is the honest answer rather than a dropped
      # filter.
      def filter_student_ids
        submitted = params.key?(:student_ids) ? Array(params.permit(student_ids: [])[:student_ids]) : []
        (submitted + [params[:student_id]]).compact_blank.uniq
      end

      def set_calendar_event
        id, @occurrence_date = CalendarEventSerializer.parse_id(params[:id])
        @calendar_event = current_teacher.calendar_events.find_by(id: id)
        render_not_found('Calendar event') if @calendar_event.nil?
      end

      # These read top-level params on purpose. The client sends camelCase and
      # ApplicationController underscores every key, so start_time and friends
      # are here by the time permit runs. Do not switch to
      # params.require(:calendar_event): wrap_parameters builds that copy from
      # the keys as they arrive, matched against column names, so a camelCase
      # startTime never matches start_time and is left out. The wrapper holds
      # only title, notes and location, and require would drop the timestamps
      # and the all day flag silently, with no error.
      def calendar_event_params
        params.permit(:title, :notes, :location, :start_time, :end_time, :all_day)
      end

      # created_time_zone records the zone the event was created in, so it is
      # accepted on create only. Absent, the model falls back to the teacher's
      # effective zone.
      def create_params
        params.permit(:title, :notes, :location, :start_time, :end_time, :all_day, :created_time_zone)
      end

      def render_missing_range
        render_error(
          'start_date and end_date are required and must be valid dates',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity
        )
      end

      def save_with_attendees(event, attendee_ids)
        event.transaction do
          event.save!
          event.student_ids = attendee_ids unless attendee_ids.nil?
        end
        event.students.reload
      end

      # Parsing the window is its own idea and lives in CalendarRange: how a
      # bare date becomes a pair of instants has nothing to do with handling a
      # request.
      def parsed_range
        CalendarRange.call(
          start_date: params[:start_date],
          end_date: params[:end_date],
          time_zone: current_teacher.effective_time_zone
        )
      end
    end
  end
end
