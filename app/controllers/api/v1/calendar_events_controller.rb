# frozen_string_literal: true

module Api
  module V1
    class CalendarEventsController < BaseController
      before_action :set_calendar_event, only: %i[show update destroy]

      # GET /api/v1/calendar_events?start_date=&end_date=&student_id=
      def index
        range = parsed_range
        return render_missing_range if range.nil?

        events = current_teacher.calendar_events.in_range(*range).chronological
        events = events.for_student(params[:student_id]) if params[:student_id].present?

        render_success(events.map { |event| CalendarEventSerializer.render(event) })
      end

      # GET /api/v1/calendar_events/:id
      def show
        render_success(CalendarEventSerializer.render(@calendar_event))
      end

      # POST /api/v1/calendar_events
      def create
        attendee_ids = submitted_attendee_ids
        return render_unowned_attendees if attendee_ids && !attendees_owned?(attendee_ids)

        event = current_teacher.calendar_events.build(create_params)
        return render_validation_errors(event) unless event.valid?

        save_with_attendees(event, attendee_ids)
        render_created(CalendarEventSerializer.render(event))
      end

      # PATCH /api/v1/calendar_events/:id
      # A submitted attendee array replaces the existing set outright.
      def update
        attendee_ids = submitted_attendee_ids
        return render_unowned_attendees if attendee_ids && !attendees_owned?(attendee_ids)

        @calendar_event.assign_attributes(calendar_event_params)
        return render_validation_errors(@calendar_event) unless @calendar_event.valid?

        save_with_attendees(@calendar_event, attendee_ids)
        render_success(CalendarEventSerializer.render(@calendar_event))
      end

      # DELETE /api/v1/calendar_events/:id
      # Hard delete: attendee rows go with it via the association and the
      # database cascade.
      def destroy
        @calendar_event.destroy
        render_no_content
      end

      private

      def set_calendar_event
        @calendar_event = current_teacher.calendar_events.find_by(id: params[:id])
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

      # nil means the client did not submit attendees at all, so the existing
      # set is left alone. An empty array clears it.
      def submitted_attendee_ids
        return nil unless params.key?(:student_ids)

        Array(params.permit(student_ids: [])[:student_ids]).uniq
      end

      def attendees_owned?(student_ids)
        return true if student_ids.empty?

        current_teacher.students.where(id: student_ids).count == student_ids.size
      end

      def render_missing_range
        render_error(
          'start_date and end_date are required and must be valid dates',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity
        )
      end

      def render_unowned_attendees
        render_error(
          'Validation failed',
          code: 'VALIDATION_ERROR',
          status: :unprocessable_entity,
          details: { student_ids: ['must all belong to the current teacher'] }
        )
      end

      def save_with_attendees(event, attendee_ids)
        event.transaction do
          event.save!
          event.student_ids = attendee_ids unless attendee_ids.nil?
        end
        event.students.reload
      end

      def parsed_range
        range_start = parse_boundary(params[:start_date], :beginning_of_day)
        range_end = parse_boundary(params[:end_date], :end_of_day)
        return nil if range_start.nil? || range_end.nil?

        [range_start, range_end]
      end

      # A bare date names one of the teacher's local days, so it widens to that
      # day's bounds in their zone. A value that already carries a time is an
      # instant the client chose: it is used as sent, with an explicit offset
      # honored rather than reinterpreted. Either way the result converts back
      # to UTC for the query.
      def parse_boundary(value, edge)
        return nil if value.blank?

        raw = value.to_s
        raw.match?(/[T ]\d/) ? parse_instant(raw) : parse_local_day(raw, edge)
      end

      def parse_instant(raw)
        Time.zone.parse(raw)
      rescue ArgumentError
        nil
      end

      def parse_local_day(raw, edge)
        teacher_zone.parse(raw)&.public_send(edge)
      rescue ArgumentError
        nil
      end

      def teacher_zone
        ActiveSupport::TimeZone[current_teacher.effective_time_zone] || Time.zone
      end
    end
  end
end
