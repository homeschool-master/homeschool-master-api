# frozen_string_literal: true

class AssignmentGradeSerializer
  def self.render(grade)
    new(grade).to_h
  end

  def initialize(grade)
    @grade = grade
  end

  # percentage rides along because every client that shows a score shows it as
  # a percentage, and recomputing it needs the assignment's points_possible,
  # which a grade row on its own does not carry.
  def to_h
    {
      id: @grade.id,
      assignment_id: @grade.assignment_id,
      student_id: @grade.student_id,
      points_earned: @grade.points_earned,
      percentage: percentage,
      graded: @grade.graded?,
      graded_at: @grade.graded_at,
      notes: @grade.notes
    }
  end

  private

  def percentage
    fraction = @grade.fraction
    fraction.nil? ? nil : (fraction * 100).round(2)
  end
end
