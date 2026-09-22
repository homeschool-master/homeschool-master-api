# frozen_string_literal: true

# One document filed against one thing.
#
# occurrence_date null means the record itself: an ordinary task, a one off
# event, or a whole series. A date means that single occurrence of a repeating
# series, which is almost always what a receipt belongs to.
class DocumentAttachment < ApplicationRecord
  # What a document can be filed against. A string list rather than a column
  # per type, so a fourth attachable is one entry here.
  ATTACHABLE_TYPES = %w[Assignment Task CalendarEvent].freeze
  # Only these two ever produce occurrences, so only these two can carry a date.
  RECURRABLE_TYPES = %w[Task CalendarEvent].freeze

  # Associations
  belongs_to :document
  belongs_to :attachable, polymorphic: true

  # Validations
  validates :attachable_type, inclusion: { in: ATTACHABLE_TYPES }
  # The two partial indexes are the real guarantee; this is here so filing the
  # same document twice comes back as a refusal rather than a database error.
  validates :document_id, uniqueness: {
    scope: %i[attachable_type attachable_id occurrence_date],
    message: 'is already filed against this'
  }
  validate :occurrence_belongs_to_something_that_recurs
  validate :attachable_belongs_to_the_same_teacher

  scope :for_record, lambda { |type, id|
    where(attachable_type: type, attachable_id: id)
  }

  # A filing follows the occurrence it names, the way a tick does.
  #
  # Editing one Tuesday out of a series makes that Tuesday a record of its own.
  # The receipt filed against that date belongs to it: leaving the filing on a
  # date the series no longer produces would take the document off the event a
  # teacher is looking at, for a reason she cannot see.
  def self.move_occurrence(from, to, date)
    for_record(from.class.name, from.id)
      .where(occurrence_date: date)
      .update_all(attachable_type: to.class.name, attachable_id: to.id,
                  occurrence_date: nil, updated_at: Time.current)
  end

  # Splitting a series hands everything from this occurrence onward to a new
  # one, so the filings on those dates go with it and keep their dates.
  def self.move_occurrences_from(from, to, date)
    for_record(from.class.name, from.id)
      .where(occurrence_date: date..)
      .update_all(attachable_type: to.class.name, attachable_id: to.id,
                  updated_at: Time.current)
  end

  def occurrence?
    occurrence_date.present?
  end

  private

  # A date has to name an occurrence that exists. On an assignment, or on an
  # event that happens once, it names nothing, and a filing nobody can see is
  # worse than a refusal.
  def occurrence_belongs_to_something_that_recurs
    return if occurrence_date.blank?
    return if RECURRABLE_TYPES.include?(attachable_type) && attachable&.recurrence.present?

    errors.add(:occurrence_date, 'is only meaningful on something that repeats')
  end

  # The document and the thing it is filed against must belong to the same
  # teacher. Without this a teacher could file her own document against
  # somebody else's assignment and learn that it exists.
  def attachable_belongs_to_the_same_teacher
    return if attachable.nil? || document.nil?
    return if attachable.teacher_id == document.teacher_id

    errors.add(:attachable, 'must belong to the same teacher')
  end
end
