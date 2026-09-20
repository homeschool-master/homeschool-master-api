# frozen_string_literal: true

# One occurrence that does not follow its series: deleted when replacement_id
# is null, replaced by that standalone row when it is set.
class RecurrenceException < ApplicationRecord
  # Associations
  belongs_to :recurrence

  # Validations
  validates :occurrence_date, presence: true
  validates :occurrence_date, uniqueness: { scope: :recurrence_id }

  # Scopes
  scope :on_or_after, ->(date) { where(occurrence_date: date..) }
  scope :deletions, -> { where(replacement_id: nil) }
  scope :replacements, -> { where.not(replacement_id: nil) }

  def deletion?
    replacement_id.nil?
  end
end
