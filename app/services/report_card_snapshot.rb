# frozen_string_literal: true

# Freezes a report card at the moment it is issued.
#
# Everything the card will ever need to render is copied onto it here: each
# subject's figures, the assignment rows those figures were summed from, and
# the overall roll up. After this runs, nothing about the card reads an
# assignment again, so rescoring work afterwards cannot reach it.
#
# The rows are captured whole rather than as a count. A card that kept only the
# percentage could not show a reader what it was based on, and recomputing the
# list later would undo the freezing. They are stored in exactly the shape
# ProgressEntrySerializer already produces, so a stored card and a live
# gradebook draw from one definition rather than two.
class ReportCardSnapshot
  def self.call(card)
    new(card).call
  end

  def initialize(card)
    @card = card
  end

  # The live report for this card's student over this card's period. Also used
  # to render a draft, which computes rather than stores.
  def report
    @report ||= ProgressReport.call(
      student: @card.student, from: @card.period_start, to: @card.period_end
    )
  end

  def call
    @card.transaction do
      capture_entries
      capture_overall
      now = Time.current
      @card.update!(captured_at: now, issued_at: now)
    end

    @card
  end

  private

  # One entry per subject in the period. Any comment or override the teacher
  # already set on a draft is kept: those are hers, not calculated, so they
  # survive the capture rather than being overwritten by it.
  def capture_entries
    report[:subjects].each_with_index do |subject, index|
      entry = @card.report_card_entries.find_or_initialize_by(subject_id: subject[:subject_id])
      entry.assign_attributes(figures_for(subject).merge(position: index))
      entry.save!
    end

    # A subject the teacher commented on that has since lost all its work in
    # this period keeps its line, with nothing calculated on it.
    @card.report_card_entries.reload
  end

  def figures_for(subject) # rubocop:disable Metrics/MethodLength
    {
      subject_name: subject[:subject_name],
      percentage: subject[:percentage],
      letter: subject[:letter],
      points_earned: subject[:points_earned],
      points_possible: subject[:points_possible],
      assigned_count: subject[:assigned_count],
      graded_count: subject[:graded_count],
      ungraded_count: subject[:ungraded_count],
      assignments: subject[:assignments]
    }
  end

  def capture_overall
    overall = report[:overall]
    @card.assign_attributes(
      overall_percentage: overall[:percentage],
      overall_letter: overall[:letter]
    )
  end
end
