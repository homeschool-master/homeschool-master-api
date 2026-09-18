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
  def to_h
    {
      id: @task.id,
      teacher_id: @task.teacher_id,
      title: @task.title,
      description: @task.description,
      due_date: @task.due_date,
      completed: @task.completed,
      completed_at: @task.completed_at,
      created_at: @task.created_at
    }
  end
end
