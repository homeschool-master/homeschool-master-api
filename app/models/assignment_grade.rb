# frozen_string_literal: true

# One student's standing on one assignment. The row existing means the student
# has been given the work. points_earned null means it has not been marked yet.
class AssignmentGrade < ApplicationRecord
  # Callbacks
  before_save :sync_graded_at
  before_save :nullify_blank_notes

  # Associations
  belongs_to :assignment
  belongs_to :student

  # Validations
  # No upper bound: a score above points_possible is extra credit, which is a
  # real thing teachers do, and capping it silently would lose marks.
  validates :points_earned, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :student_id, uniqueness: { scope: :assignment_id }
  # Provenance only. points_earned is still the number everything calculates
  # with, so a letter that is not on the scale is rejected rather than quietly
  # stored beside a score it does not describe.
  validates :entered_letter, inclusion: { in: LetterScale.letters }, allow_nil: true
  validate :entered_letter_has_a_score
  validate :student_belongs_to_assignment_teacher

  # Scopes
  scope :graded, -> { where.not(points_earned: nil) }
  scope :ungraded, -> { where(points_earned: nil) }

  def graded?
    points_earned.present?
  end

  # True when the teacher picked a letter rather than typing a number. What she
  # sees when she reopens the mark follows from this: the letter she chose,
  # rather than the score it became.
  def entered_as_letter?
    entered_letter.present?
  end

  # Records a mark from a letter. The score is worked out once, here, and
  # stored: deriving it on read would mean a later change to the key silently
  # rewriting marks a teacher already gave.
  def apply_letter(letter)
    self.entered_letter = LetterScale.normalize(letter)
    self.points_earned = LetterScale.score_for(letter, assignment&.points_possible)
  end

  # This student's share of the assignment, as a fraction rather than a
  # percentage, so the weighting arithmetic stays in one unit. Nil while
  # ungraded, which is what keeps an unmarked assignment out of the average.
  def fraction
    return nil unless graded?

    points_earned / assignment.points_possible
  end

  private

  # Same shape as the task's completed_at: the timestamp follows the value
  # rather than being set by the client, and clearing the score clears it.
  def sync_graded_at
    if points_earned.nil?
      self.graded_at = nil
      # A cleared mark was not entered as anything, so the letter goes with it.
      self.entered_letter = nil
    else
      self.graded_at ||= Time.current
    end
  end

  def entered_letter_has_a_score
    return if entered_letter.blank? || points_earned.present?

    errors.add(:entered_letter, 'needs a score')
  end

  def nullify_blank_notes
    self.notes = nil if notes.blank?
  end

  def student_belongs_to_assignment_teacher
    return if student_id.blank? || assignment.nil?
    return if assignment.teacher.students.exists?(id: student_id)

    errors.add(:student_id, 'must belong to the current teacher')
  end
end
