# frozen_string_literal: true

# One subject's line on a report card, and on an issued card the whole of what
# that line is based on.
class ReportCardEntry < ApplicationRecord
  # Associations
  belongs_to :report_card
  # Optional: a subject removed after the card was issued leaves the line in
  # place, which still reads because the name is stored here too.
  belongs_to :subject, optional: true

  # Validations
  validates :subject_name, presence: true, length: { maximum: 100 }
  validates :override_letter, inclusion: { in: LetterScale.letters }, allow_nil: true
  validate :issued_card_entry_is_untouched, on: :update

  def overridden?
    override_letter.present?
  end

  # What this line says: her letter when she set one, the calculated one
  # otherwise. The calculated letter is kept either way, so a card can show
  # what an override replaced.
  def effective_letter
    override_letter.presence || letter
  end

  # The work this line was summed from. An empty list on a draft simply means
  # it has not been captured yet: a draft reads its rows live.
  def captured_assignments
    assignments || []
  end

  private

  def issued_card_entry_is_untouched
    return unless report_card&.issued?
    # The entry is filled in as part of issuing, which happens while the card
    # is still being issued rather than after.
    return if report_card.issued_at_previously_changed?

    errors.add(:base, 'An issued report card cannot be changed. Create a new version instead.')
  end
end
