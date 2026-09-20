# frozen_string_literal: true

class Task < ApplicationRecord
  # Callbacks
  before_save :nullify_blank_description

  # Whose job the task is. Naming students cannot express this on its own:
  # "Export report cards" names Scarlett and is the teacher's work, while
  # "Finish the science fair project" names her and is hers. Stored as one
  # column rather than two booleans, because the three states are exclusive and
  # a pair of flags can hold a fourth that means nothing: neither.
  OWNERS = %w[teacher student both].freeze

  # Associations
  belongs_to :teacher

  has_many :task_students, dependent: :destroy
  has_many :students, through: :task_students

  # A series carries its rule; an ordinary task has none, which is what keeps
  # every task created before this feature working untouched.
  has_one :recurrence, as: :recurrable, dependent: :destroy
  # The ticked occurrences of a series. An ordinary task has none: its
  # completion is the completed_at column below.
  has_many :task_completions, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :owned_by, inclusion: { in: OWNERS }
  validate :student_owned_task_names_a_student
  validate :repeating_task_has_a_due_date

  # Scopes
  scope :open, -> { where(completed_at: nil) }
  # Any of them, not all of them: a task shared by two children is one of
  # each child's tasks rather than only of the pair's.
  scope :for_students, lambda { |student_ids|
    joins(:task_students).where(task_students: { student_id: student_ids }).distinct
  }
  # The two halves of ownership, each a question about whose job it is rather
  # than about who the task concerns.
  scope :owned_by_teacher, -> { where(owned_by: %w[teacher both]) }
  scope :owned_by_student, -> { where(owned_by: %w[student both]) }
  scope :completed, -> { where.not(completed_at: nil) }
  # Inclusive: a task due on the boundary day is due by it. Undated tasks are
  # not due by any date, so they are left out rather than swept in.
  scope :due_by, ->(date) { where(due_date: ..date) }
  # Soonest first, undated last: a task with no due date is not due soon, so it
  # belongs at the end of a list the dashboard reads from the top.
  scope :by_due_date, -> { order(Arel.sql('due_date ASC NULLS LAST, created_at ASC')) }

  # Tasks that repeat, and tasks that do not. Every query has to serve both:
  # one row stands for itself, the other stands for a series to be expanded.
  scope :single, -> { where.missing(:recurrence) }
  scope :series, -> { where.associated(:recurrence) }
  # A series can reach a window when it is anchored on or before the end of it
  # and has not already finished by the start of it. Whether it actually lands
  # inside is the schedule's business, not the query's.
  scope :series_reaching, lambda { |to, from|
    series.where(due_date: ..to)
          .where('recurrences.until_date IS NULL OR recurrences.until_date >= ?', from)
  }

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

  # True when a student is on the hook for this, which is a different question
  # from whether the task names one.
  def student_owned?
    owned_by != 'teacher'
  end

  def recurring?
    recurrence.present?
  end

  # The day the series repeats from. A task with no due date has no anchor, so
  # it cannot repeat: there is no date to step forward from.
  def anchor_date
    due_date
  end

  private

  # A task that is a student's has to say whose. "Finish the science fair
  # project", owned by a student and naming none, records an owner that does
  # not exist, and it would silently drop out of every student's list while
  # still claiming not to be the teacher's.
  #
  # Removing the last student from such a task is refused rather than quietly
  # turning it back into the teacher's own: which of the two a teacher meant is
  # not something this can know, and guessing changes what the task says.
  def student_owned_task_names_a_student
    return unless student_owned?
    return if students.any? || task_students.any?

    errors.add(:student_ids, 'must name at least one student when the task is a student\'s')
  end

  # There is nothing to repeat from without one. The form hides the repeat
  # controls until a date is picked, and this is the same rule stated where it
  # cannot be bypassed.
  def repeating_task_has_a_due_date
    return if recurrence.nil? || due_date.present?

    errors.add(:due_date, 'is needed before a task can repeat')
  end

  def nullify_blank_description
    self.description = nil if description.blank?
  end
end
