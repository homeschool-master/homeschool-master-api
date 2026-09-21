# frozen_string_literal: true

# A saved copy of one student's grades for a period.
#
# Two states, told apart by issued_at the way a task is told apart by
# completed_at:
#
#   draft    freely editable, and its figures are computed live from current
#            grades every time it is read. Nothing is frozen, so a teacher who
#            marks more work on Tuesday sees it on the draft she started on
#            Monday without having to know to refresh anything.
#   issued   frozen. Every figure and every assignment row it was summed from
#            is stored on its entries, and nothing here reads an assignment
#            again. Rescoring afterwards cannot reach it.
#
# Editing an issued card is not an edit: it creates the next version, leaving
# the one that was handed over exactly as it was.
class ReportCard < ApplicationRecord
  # Associations
  belongs_to :teacher
  belongs_to :student
  has_many :report_card_entries, -> { order(:position, :subject_name) },
           dependent: :destroy, inverse_of: :report_card

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :version, numericality: { greater_than: 0 }
  validates :overall_override_letter, inclusion: { in: LetterScale.letters }, allow_nil: true
  validate :period_ends_after_it_starts
  validate :student_belongs_to_teacher
  # The whole point of the table, enforced here rather than left to whoever
  # remembers: once a card has been issued it cannot be changed at all.
  validate :issued_card_is_untouched, on: :update

  # Scopes
  scope :issued, -> { where.not(issued_at: nil) }
  scope :drafts, -> { where(issued_at: nil) }
  scope :newest_first, -> { order(period_start: :desc, created_at: :desc) }
  # One row per card rather than one per version: the highest version in each
  # group is the one that stands.
  scope :current_versions, lambda {
    where(version: unscoped.select('MAX(version)').where('report_cards.group_id = group_id'))
  }

  def issued?
    issued_at.present?
  end

  # Whether this card's figures are frozen. Always true once issued, and true
  # before that on a version inherited from an issued card. It is this, not
  # issued?, that decides whether the card is read or computed.
  def captured?
    captured_at.present?
  end

  def draft?
    !issued?
  end

  # Every version of this card, oldest first.
  def versions
    self.class.where(teacher_id: teacher_id, group_id: group_id).order(:version)
  end

  def latest_version?
    !self.class.where(group_id: group_id).where('version > ?', version).exists?
  end

  # What the card says overall: the teacher's letter when she set one, and the
  # calculated one otherwise.
  def effective_overall_letter
    overall_override_letter.presence || overall_letter
  end

  def overall_overridden?
    overall_override_letter.present?
  end

  private

  def period_ends_after_it_starts
    return if period_start.blank? || period_end.blank? || period_end >= period_start

    errors.add(:period_end, 'must be on or after the period start')
  end

  def student_belongs_to_teacher
    return if student_id.blank? || teacher_id.blank?
    return if teacher.students.exists?(id: student_id)

    errors.add(:student_id, 'must belong to the current teacher')
  end

  # issued_at going from nil to a time is the act of issuing, which is allowed.
  # Anything else on a card that was already issued is not.
  def issued_card_is_untouched
    return unless issued_at_was.present?

    errors.add(:base, 'An issued report card cannot be changed. Create a new version instead.')
  end
end
