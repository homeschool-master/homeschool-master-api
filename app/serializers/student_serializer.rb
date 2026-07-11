# frozen_string_literal: true

class StudentSerializer
  def self.render(student)
    new(student).to_h
  end

  def initialize(student)
    @student = student
  end

  def to_h # rubocop:disable Metrics/MethodLength
    {
      id: @student.id,
      teacher_id: @student.teacher_id,
      first_name: @student.first_name,
      middle_name: @student.middle_name,
      last_name: @student.last_name,
      grade_level: @student.grade_level,
      color: @student.color,
      profile_image_url: @student.profile_image_url,
      is_active: @student.is_active,
      created_at: @student.created_at
    }
  end
end
