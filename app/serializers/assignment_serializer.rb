# frozen_string_literal: true

class AssignmentSerializer
  def self.render(assignment)
    new(assignment).to_h
  end

  def initialize(assignment)
    @assignment = assignment
  end

  # Grades are nested rather than reduced to ids, unlike calendar event
  # attendees. There the ids kept a month of several hundred events small; here
  # the grades are the substance of the record and a family has a handful of
  # students, so an assignment row renders from one response.
  def to_h # rubocop:disable Metrics/MethodLength
    {
      id: @assignment.id,
      teacher_id: @assignment.teacher_id,
      subject_id: @assignment.subject_id,
      assignment_type_id: @assignment.assignment_type_id,
      # The name rides along so a row can say what kind of work it is without
      # the client holding the whole type list to look it up.
      assignment_type_name: @assignment.assignment_type&.name,
      title: @assignment.title,
      description: @assignment.description,
      due_date: @assignment.due_date,
      points_possible: @assignment.points_possible,
      weight: @assignment.weight,
      # Says whether this number came from the type or from the teacher, which
      # is what lets the form tell her a later default change will or will not
      # move it.
      weight_overridden: @assignment.weight_overridden,
      grades: @assignment.assignment_grades.map { |grade| AssignmentGradeSerializer.render(grade) },
      created_at: @assignment.created_at
    }
  end
end
