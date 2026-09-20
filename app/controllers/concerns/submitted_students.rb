# frozen_string_literal: true

# Reading a submitted set of students and checking it belongs to the teacher.
#
# Shared by calendar events and tasks, which had the same three methods under
# two sets of names: an event called them attendees and a task called them
# students, but the rule was identical in both. One id belonging to another
# teacher rejects the whole request rather than being dropped from it, because
# a record quietly saved without the student it named is worse than one that
# was refused.
module SubmittedStudents
  extend ActiveSupport::Concern

  private

  # nil means the client did not submit students at all, so the existing set is
  # left alone. An empty array clears it.
  def submitted_student_ids
    return nil unless params.key?(:student_ids)

    Array(params.permit(student_ids: [])[:student_ids]).uniq
  end

  def students_owned?(student_ids)
    return true if student_ids.empty?

    current_teacher.students.where(id: student_ids).count == student_ids.size
  end

  # Loaded through the teacher, so an id belonging to someone else cannot
  # arrive even if the check above were ever bypassed.
  def students_for(student_ids)
    return [] if student_ids.empty?

    current_teacher.students.where(id: student_ids).to_a
  end

  def render_unowned_students
    render_error(
      'Validation failed',
      code: 'VALIDATION_ERROR',
      status: :unprocessable_entity,
      details: { student_ids: ['must all belong to the current teacher'] }
    )
  end
end
