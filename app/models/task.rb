# frozen_string_literal: true

class Task < ApplicationRecord
  # Callbacks
  before_save :nullify_blank_description

  # Associations
  belongs_to :teacher

  # Validations
  validates :title, presence: true, length: { maximum: 255 }

  # Scopes
  scope :open, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  # Inclusive: a task due on the boundary day is due by it. Undated tasks are
  # not due by any date, so they are left out rather than swept in.
  scope :due_by, ->(date) { where(due_date: ..date) }
  # Soonest first, undated last: a task with no due date is not due soon, so it
  # belongs at the end of a list the dashboard reads from the top.
  scope :by_due_date, -> { order(Arel.sql('due_date ASC NULLS LAST, created_at ASC')) }

  # Completion is stored as the instant it happened, not as a boolean. The two
  # are not equivalent: the timestamp answers "is it done" as well as a flag
  # does, and also answers when, which a flag throws away. It matches how the
  # rest of the app records events, email_verified_at and graded_at among them,
  # and it cannot drift the way a separate flag and timestamp can.
  #
  # Clients that only want the checkbox get these two accessors, so nothing has
  # to reason about nulls to render a tick.
  # Not completed?: this is the reader half of an attribute, paired with the
  # writer below, so update(completed: true) and permit(:completed) have
  # something to bind to. The predicate form is aliased underneath it, the way
  # Rails gives a real boolean column both.
  # rubocop:disable Naming/PredicateMethod
  def completed
    completed_at.present?
  end
  # rubocop:enable Naming/PredicateMethod

  alias completed? completed

  # Re-completing an already finished task keeps the original time rather than
  # moving it, so a double tap on a checkbox does not rewrite history.
  def completed=(value)
    if ActiveModel::Type::Boolean.new.cast(value)
      self.completed_at ||= Time.current
    else
      self.completed_at = nil
    end
  end

  private

  def nullify_blank_description
    self.description = nil if description.blank?
  end
end
