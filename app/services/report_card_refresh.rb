# frozen_string_literal: true

# Pulls a draft's frozen figures back up to date with current grades.
#
# Only a version inherited from an issued card has frozen figures to refresh:
# a first draft computes live already and has nothing to pull. The usual reason
# to want this is a marking error found after a card went out, where the honest
# fix is a new version carrying the corrected grades.
#
# It is an explicit act rather than something editing does on its own, so that
# the figures on a card never move without the teacher asking them to.
class ReportCardRefresh
  def self.call(card)
    new(card).call
  end

  def initialize(card)
    @card = card
  end

  def call
    raise ArgumentError, 'an issued card cannot be refreshed' if @card.issued?

    @card.transaction do
      # Clearing first, so a subject that has lost all its work in the period
      # does not keep figures from the version this one was copied from.
      @card.report_card_entries.update_all(
        percentage: nil, letter: nil, points_earned: nil, points_possible: nil,
        assigned_count: nil, graded_count: nil, ungraded_count: nil, assignments: nil,
        updated_at: Time.current
      )
      # Clearing captured_at is what puts the card back to computing live.
      @card.update!(overall_percentage: nil, overall_letter: nil, captured_at: nil)
    end

    @card.reload
  end
end
