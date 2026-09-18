# frozen_string_literal: true

class SubjectSerializer
  def self.render(subject)
    new(subject).to_h
  end

  def initialize(subject)
    @subject = subject
  end

  def to_h
    {
      id: @subject.id,
      teacher_id: @subject.teacher_id,
      name: @subject.name,
      color: @subject.color,
      description: @subject.description,
      is_active: @subject.is_active,
      created_at: @subject.created_at
    }
  end
end
