# frozen_string_literal: true

# What a report card says, whichever state it is in.
#
# One shape out, two ways in, and the difference is the whole design:
#
#   captured   read from the entries stored on the card. No assignment is
#              touched, so the card cannot change. Always true once issued, and
#              true on a version inherited from an issued card.
#   not yet    computed live from current grades every time it is read, with
#              whatever the teacher has already written or overridden laid over
#              the top.
#
# A draft computes live rather than capturing at creation because the opposite
# is a trap: a teacher who starts a card on Monday and marks work on Tuesday
# would be looking at stale figures and would have to know that a refresh
# control existed. Freezing is a thing she does on purpose, once, by issuing.
class ReportCardView
  def self.call(card)
    new(card).call
  end

  def initialize(card)
    @card = card
  end

  def call
    {
      subjects: subjects,
      overall: overall
    }
  end

  private

  def subjects
    @card.captured? ? stored_subjects : live_subjects
  end

  def stored_subjects
    @card.report_card_entries.map { |entry| line(stored_figures(entry), entry) }
  end

  # The live report, with the teacher's own comments and overrides laid over
  # it by subject. Her words are stored from the moment she writes them; only
  # the arithmetic is recomputed.
  def live_subjects
    report[:subjects].map { |subject| line(subject, entries_by_subject[subject[:subject_id]]) }
  end

  def entries_by_subject
    @entries_by_subject ||= @card.report_card_entries.index_by(&:subject_id)
  end

  # An entry read back in the same shape ProgressReport produces, so one
  # builder serves both a stored card and a live one.
  def stored_figures(entry)
    {
      subject_id: entry.subject_id, subject_name: entry.subject_name,
      percentage: entry.percentage, letter: entry.letter,
      points_earned: entry.points_earned, points_possible: entry.points_possible,
      assigned_count: entry.assigned_count, graded_count: entry.graded_count,
      ungraded_count: entry.ungraded_count, assignments: entry.captured_assignments
    }
  end

  # The calculated figures, plus what the teacher put over them. Both halves
  # go out: an override that hid the number it replaced would not be honest.
  def line(figures, entry)
    figures.merge(
      override_letter: entry&.override_letter,
      override_reason: entry&.override_reason,
      overridden: entry&.overridden? || false,
      effective_letter: entry&.override_letter.presence || figures[:letter],
      comments: entry&.comments
    )
  end

  def overall
    calculated = calculated_overall

    calculated.merge(
      override_letter: @card.overall_override_letter,
      override_reason: @card.overall_override_reason,
      overridden: @card.overall_overridden?,
      effective_letter: @card.overall_override_letter.presence || calculated[:letter]
    )
  end

  def calculated_overall
    return { percentage: @card.overall_percentage, letter: @card.overall_letter } if @card.captured?

    report[:overall].slice(:percentage, :letter)
  end

  def report
    @report ||= ProgressReport.call(
      student: @card.student, from: @card.period_start, to: @card.period_end
    )
  end
end
