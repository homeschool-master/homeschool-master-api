# frozen_string_literal: true

# The next version of an issued report card.
#
# Editing an issued card does not change it: it makes a new one beside it. The
# version handed over stays exactly as it was and stays readable, which is the
# only thing that makes "what she gave the co-op still says what it said" true.
#
# Versions are numbered from 1, in sequence. A number is what a reader refers
# to ("version 2 of the autumn report") and it orders the set without anyone
# having to compare timestamps.
#
# What carries forward is everything, including the frozen figures. A new
# version starts as a draft, but a draft made this way does not recompute:
# it inherits the snapshot it is superseding. That is deliberate. The usual
# reason to reissue is to fix a comment or add an override, and recomputing
# would silently change the grades as well as the words. A teacher who does
# want the current figures asks for that explicitly with refresh, which is a
# visible act rather than a side effect of editing.
class ReportCardVersion
  COPIED_FROM_CARD = %i[
    teacher_id student_id group_id title period_start period_end comments
    overall_percentage overall_letter overall_override_letter overall_override_reason
    captured_at
  ].freeze

  COPIED_FROM_ENTRY = %i[
    subject_id subject_name percentage letter points_earned points_possible
    assigned_count graded_count ungraded_count assignments
    override_letter override_reason comments position
  ].freeze

  def self.call(card)
    new(card).call
  end

  def initialize(card)
    @card = card
  end

  def call
    ReportCard.transaction do
      copy = ReportCard.create!(@card.slice(*COPIED_FROM_CARD).merge('version' => next_version))
      @card.report_card_entries.each do |entry|
        copy.report_card_entries.create!(entry.slice(*COPIED_FROM_ENTRY))
      end
      copy
    end
  end

  private

  # Counted across the whole group rather than from this card, so two edits of
  # the same version cannot both claim to be version 2.
  def next_version
    ReportCard.where(group_id: @card.group_id).maximum(:version).to_i + 1
  end
end
