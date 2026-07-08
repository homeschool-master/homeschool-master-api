# frozen_string_literal: true

module Api
  module V1
    class StudentsController < BaseController
      before_action :set_student, only: %i[show update destroy]

      # GET /api/v1/students
      def index
        students = current_teacher.students.active.order(created_at: :asc)
        render_success(students.map { |student| StudentSerializer.render(student) })
      end

      # GET /api/v1/students/:id
      def show
        render_success(StudentSerializer.render(@student))
      end

      # POST /api/v1/students
      def create
        student = current_teacher.students.build(student_params)

        if student.save
          render_created(StudentSerializer.render(student))
        else
          render_validation_errors(student)
        end
      end

      # PATCH /api/v1/students/:id
      def update
        if @student.update(student_params)
          render_success(StudentSerializer.render(@student))
        else
          render_validation_errors(@student)
        end
      end

      # DELETE /api/v1/students/:id
      # Soft delete: flips is_active to false so dependent records survive.
      def destroy
        @student.update(is_active: false)
        render_no_content
      end

      private

      def set_student
        @student = current_teacher.students.find_by(id: params[:id])
        render_not_found('Student') if @student.nil?
      end

      def student_params
        params.permit(:first_name, :last_name, :grade_level, :color, :profile_image_url)
      end
    end
  end
end
