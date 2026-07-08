# frozen_string_literal: true

module Api
  module V1
    class StudentsController < BaseController
      # POST /api/v1/students
      def create
        student = current_teacher.students.build(student_params)

        if student.save
          render_created(StudentSerializer.render(student))
        else
          render_validation_errors(student)
        end
      end

      private

      def student_params
        params.permit(:first_name, :last_name, :grade_level, :color)
      end
    end
  end
end
