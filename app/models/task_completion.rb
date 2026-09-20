# frozen_string_literal: true

# One ticked occurrence of a repeating task. The row existing is the tick, so
# unticking deletes it rather than clearing a column.
class TaskCompletion < ApplicationRecord
  # Associations
  belongs_to :task

  # Validations
  validates :occurrence_date, presence: true
  validates :completed_at, presence: true
  validates :occurrence_date, uniqueness: { scope: :task_id }

  # Scopes
  scope :between, ->(from, to) { where(occurrence_date: from..to) }
end
