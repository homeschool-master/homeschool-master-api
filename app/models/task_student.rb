# frozen_string_literal: true

# One student on one task. The row existing is what puts them on it, the same
# way an event attendee row works.
class TaskStudent < ApplicationRecord
  # Associations
  belongs_to :task
  belongs_to :student

  # Validations
  validates :student_id, uniqueness: { scope: :task_id, message: 'is already on this task' }
end
