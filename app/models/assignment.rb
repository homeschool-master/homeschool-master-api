# frozen_string_literal: true

class Assignment < ApplicationRecord
  # Callbacks
  before_save :nullify_blank_description
  # Only when one of the two things it describes is actually being set. A title
  # edit must not silently pin a weight, and an inherited weight that does not
  # currently equal its default is a real state: it is what "new assignments
  # only" leaves behind.
  before_save :record_weight_source,
              if: -> { will_save_change_to_weight? || will_save_change_to_assignment_type_id? }

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

  private

  # The rule in one sentence: a weight that differs from the type's default at
  # the moment the teacher sets it is a choice about this assignment, and
  # nothing that happens to the default afterwards may touch it.
  def record_weight_source
    return if assignment_type.nil?

    self.weight_overridden = weight != assignment_type.default_weight
  end

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
