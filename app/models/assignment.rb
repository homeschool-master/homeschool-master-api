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
  has_many :assignment_grades, dependent: :destroy
  has_many :students, through: :assignment_grades

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :points_possible, numericality: { greater_than: 0 }
  validates :weight, numericality: { greater_than_or_equal_to: 0 }
  validate :subject_belongs_to_teacher

  # Scopes
  scope :chronological, -> { order(Arel.sql('due_date ASC NULLS LAST, created_at ASC')) }
  scope :for_subject, ->(subject_id) { where(subject_id: subject_id) }
  # A report covers a period, and due_date is the academic date that places an
  # assignment in one. Undated work belongs to no period and is left out.
  scope :due_between, ->(from, to) { where(due_date: from..to) }

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
end
