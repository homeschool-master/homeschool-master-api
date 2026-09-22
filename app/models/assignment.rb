# frozen_string_literal: true

class Assignment < ApplicationRecord
  # Callbacks
  before_save :nullify_blank_description

  # Associations
  #
  # Students come through their grades rather than through a separate join.
  # One row per student per assignment carries both facts: that the student has
  # this work, and what they scored on it if it has been marked.
  belongs_to :teacher
  belongs_to :subject
  belongs_to :assignment_type
  has_many :assignment_grades, dependent: :destroy
  has_many :students, through: :assignment_grades

  # Files filed against this record. Destroying the record takes the join rows
  # with it and leaves the documents themselves alone: a receipt outlives the
  # event it was filed against.
  has_many :document_attachments, as: :attachable, dependent: :destroy
  has_many :documents, through: :document_attachments

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :points_possible, numericality: { greater_than: 0 }
  validates :weight, numericality: { greater_than_or_equal_to: 0 }
  validate :subject_belongs_to_teacher
  validate :assignment_type_belongs_to_teacher

  # Scopes
  scope :chronological, -> { order(Arel.sql('due_date ASC NULLS LAST, created_at ASC')) }
  scope :for_subject, ->(subject_id) { where(subject_id: subject_id) }
  scope :for_type, ->(type_id) { where(assignment_type_id: type_id) }
  # The rows a changed default is allowed to reach. An overridden weight is a
  # decision about one piece of work and outranks a default changed afterwards.
  scope :inheriting_weight, -> { where(weight_overridden: false) }
  # Undated work is left out by the comparison rather than by a special case:
  # NULL >= a date is unknown, which is also the right answer. An assignment
  # with no due date sits in no period, the same rule due_between already uses.
  scope :due_on_or_after, ->(date) { where(due_date: date..) }
  # A report covers a period, and due_date is the academic date that places an
  # assignment in one. Undated work belongs to no period and is left out.
  scope :due_between, ->(from, to) { where(due_date: from..to) }

  # Whether this assignment's weight is its own choice or its type's default.
  def weight_inherited?
    !weight_overridden?
  end

  # A weight the teacher typed, whatever the number.
  #
  # Touching the field is the decision, not the value that came out of it.
  # Comparing against the type's default instead would mean a teacher who
  # deliberately types 1 when the default is 1 gets an inherited weight, and
  # the next change to that default moves work she had already settled.
  def override_weight!(value)
    self.weight = value
    self.weight_overridden = true
  end

  # Hands the assignment back to its type, so it follows the default again.
  def inherit_weight!
    self.weight = assignment_type&.default_weight
    self.weight_overridden = false
  end

  private

  def nullify_blank_description
    self.description = nil if description.blank?
  end

  # The subject is chosen by id from the client, so it has to be checked the
  # way calendar event attendees are: a valid uuid belonging to someone else is
  # a different code path from a malformed one.
  def subject_belongs_to_teacher
    return if subject_id.blank? || teacher_id.blank?
    return if teacher.subjects.exists?(id: subject_id)

    errors.add(:subject_id, 'must belong to the current teacher')
  end

  # Same check as the subject, for the same reason: the id comes from the
  # client, and one belonging to another family is a different failure from a
  # malformed one.
  def assignment_type_belongs_to_teacher
    return if assignment_type_id.blank? || teacher_id.blank?
    return if teacher.assignment_types.exists?(id: assignment_type_id)

    errors.add(:assignment_type_id, 'must belong to the current teacher')
  end
end
