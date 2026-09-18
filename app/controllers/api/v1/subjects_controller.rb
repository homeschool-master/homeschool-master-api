# frozen_string_literal: true

module Api
  module V1
    class SubjectsController < BaseController
      before_action :set_subject, only: %i[show update destroy]

      # GET /api/v1/subjects
      # Alphabetical rather than by creation: a subject list is something the
      # teacher picks from, where the roster's creation order is meaningful.
      def index
        subjects = current_teacher.subjects.active.order(:name)
        render_success(subjects.map { |subject| SubjectSerializer.render(subject) })
      end

      # GET /api/v1/subjects/:id
      def show
        render_success(SubjectSerializer.render(@subject))
      end

      # POST /api/v1/subjects
      def create
        subject = current_teacher.subjects.build(subject_params)

        if subject.save
          render_created(SubjectSerializer.render(subject))
        else
          render_validation_errors(subject)
        end
      end

      # PATCH /api/v1/subjects/:id
      def update
        if @subject.update(subject_params)
          render_success(SubjectSerializer.render(@subject))
        else
          render_validation_errors(@subject)
        end
      end

      # DELETE /api/v1/subjects/:id
      # Soft delete: flips is_active to false so the row, and anything that
      # comes to reference it later, survives. It also releases the name, which
      # the partial unique index allows on purpose.
      def destroy
        @subject.update(is_active: false)
        render_no_content
      end

      private

      def set_subject
        @subject = current_teacher.subjects.find_by(id: params[:id])
        render_not_found('Subject') if @subject.nil?
      end

      # Top-level params, the same as students and calendar events. All three
      # of these columns happen to be spelled identically in camelCase, so
      # params.require(:subject) would survive today where it silently mangles
      # the other controllers. It would still be the wrong habit: the first
      # multi word column added here would start being dropped with no error.
      def subject_params
        params.permit(:name, :color, :description)
      end
    end
  end
end
