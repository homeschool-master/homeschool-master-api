# frozen_string_literal: true

class TaskSerializer
  def self.render(task)
    new(task).to_h
  end

  def initialize(task)
    @task = task
  end

  # Both faces of completion: the boolean a checkbox binds to, and the instant
  # it was ticked. One column behind them, so they cannot disagree.
  #
  # student_ids and owned_by answer two different questions and both are sent:
  # who the task concerns, and whose job it is. A task can name a student and
  # still be the teacher's work.
  def to_h # rubocop:disable Metrics/MethodLength
    {
      id: @task.id,
      teacher_id: @task.teacher_id,
      title: @task.title,
      description: @task.description,
      due_date: @task.due_date,
      completed: @task.completed,
      completed_at: @task.completed_at,
      owned_by: @task.owned_by,
      student_ids: @task.student_ids,
      created_at: @task.created_at
    }
  end
end
