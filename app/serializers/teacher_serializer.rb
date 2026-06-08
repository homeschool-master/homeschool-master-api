# frozen_string_literal: true

class TeacherSerializer
  def self.render(teacher)
    new(teacher).to_h
  end

  def initialize(teacher)
    @teacher = teacher
  end

  def to_h
    {
      id: @teacher.id,
      first_name: @teacher.first_name,
      last_name: @teacher.last_name,
      email: @teacher.email,
      created_at: @teacher.created_at
    }
  end
end
