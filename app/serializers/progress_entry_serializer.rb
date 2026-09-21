# frozen_string_literal: true

# One piece of work as a single student holds it, for the gradebook.
#
# Built from the same AssignmentGrade rows the progress figures are summed
# from, so the list a teacher reads and the percentage above it are one
# calculation rather than two that agree today.
#
# Everything here exists to let the reader tell four states apart: work not
# marked yet, an explicit zero, work that is marked but weighted zero so it
# counts towards nothing, and an ordinary mark.
class ProgressEntrySerializer
  def self.render(grade)
    new(grade).to_h
  end

  def initialize(grade)
    @grade = grade
    @assignment = grade.assignment
  end

  def to_h # rubocop:disable Metrics/MethodLength
    {
      assignment_id: @assignment.id,
      title: @assignment.title,
      assignment_type_name: @assignment.assignment_type&.name,
      due_date: @assignment.due_date,
      weight: @assignment.weight,
      points_possible: @assignment.points_possible,
      points_earned: @grade.points_earned,
      graded: @grade.graded?,
      percentage: percentage,
      letter: LetterScale.letter_for(percentage),
      # What she chose, when she marked it by letter rather than by number.
      entered_letter: @grade.entered_letter
    }
  end

  private

  def percentage
    return @percentage if defined?(@percentage)

    fraction = @grade.fraction
    @percentage = fraction.nil? ? nil : (fraction * 100).to_d.round(2)
  end
end
