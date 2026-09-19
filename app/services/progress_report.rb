# frozen_string_literal: true

# The weighted roll up behind "auto-calculated weighted grades by subject".
#
# For one student over one date range, grouped by subject:
#
#   percentage = sum(weight * points_earned / points_possible) / sum(weight)
#
# That is a weighted mean of each assignment's own percentage, not a mean of
# raw points. The two differ: by points, a 100 point exam already outweighs a
# 10 point quiz ten to one whether or not the teacher meant it to. Weighting
# the percentages separates "what it is out of" from "how much it counts", so
# a twenty question quiz can still be worth less than a twenty point project.
#
# Only graded work counts. An assignment a student has been given but that has
# not been marked is excluded rather than treated as zero, so a report part way
# through a term reflects the work actually marked. A teacher who means zero
# enters zero, and that counts. Both counts are reported so the reader can see
# what the number is based on.
class ProgressReport
  # 90/80/70/60, the ordinary US scale. Derived on read rather than stored, so
  # changing it costs nothing and never invalidates a saved grade.
  LETTER_THRESHOLDS = [[90, 'A'], [80, 'B'], [70, 'C'], [60, 'D']].freeze
  LOWEST_LETTER = 'F'

  def self.call(student:, from:, to:)
    new(student: student, from: from, to: to).call
  end

  def initialize(student:, from:, to:)
    @student = student
    @from = from
    @to = to
  end

  def call
    {
      student_id: @student.id,
      from: @from,
      to: @to,
      subjects: subjects,
      overall: summarize(all_rows)
    }
  end

  private

  # One query for the whole report: every grade this student holds on an
  # assignment due inside the range, with its assignment and subject alongside.
  def rows
    @rows ||= AssignmentGrade
              .where(student_id: @student.id)
              .joins(:assignment)
              .merge(Assignment.due_between(@from, @to))
              .includes(assignment: :subject)
              .to_a
  end

  def all_rows
    rows
  end

  def subjects
    rows
      .group_by { |row| row.assignment.subject }
      .sort_by { |subject, _| subject.name.to_s.downcase }
      .map { |subject, subject_rows| subject_summary(subject, subject_rows) }
  end

  def subject_summary(subject, subject_rows)
    { subject_id: subject.id, subject_name: subject.name }.merge(summarize(subject_rows))
  end

  # The shared arithmetic, used for a single subject and for the overall figure.
  # Overall weights every assignment the same way the per subject figure does,
  # rather than averaging the subject averages: there is no "how much does this
  # subject count" anywhere in the schema, and inventing one here would be a
  # second weighting concept the teacher never set.
  def summarize(subject_rows)
    graded = subject_rows.select(&:graded?)
    percentage = percentage(graded)

    counts(subject_rows, graded).merge(
      points_earned: round2(graded.sum(&:points_earned)),
      points_possible: round2(graded.sum { |row| row.assignment.points_possible }),
      percentage: percentage,
      letter: letter(percentage)
    )
  end

  # What the figure is based on, reported alongside it so a reader can see that
  # a subject average covers two marked assignments out of ten set.
  def counts(subject_rows, graded)
    {
      assigned_count: subject_rows.length,
      graded_count: graded.length,
      ungraded_count: subject_rows.length - graded.length
    }
  end

  # Nil rather than zero when there is nothing to average. No graded work and a
  # total weight of zero are both real: the second is a subject whose every
  # assignment is practice, weighted 0. Dividing either one would invent a
  # grade of 0% for a student who has simply not been marked.
  def percentage(graded)
    weight_total = graded.sum { |row| row.assignment.weight }
    return nil if graded.empty? || weight_total.zero?

    weighted = graded.sum { |row| row.assignment.weight * row.fraction }
    round2(weighted / weight_total * 100)
  end

  def letter(percentage)
    return nil if percentage.nil?

    LETTER_THRESHOLDS.each { |threshold, letter| return letter if percentage >= threshold }
    LOWEST_LETTER
  end

  def round2(value)
    return nil if value.nil?

    value.to_d.round(2)
  end
end
