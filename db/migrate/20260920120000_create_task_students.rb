# frozen_string_literal: true

# Students on a task, the same shape as event attendees: one row per student
# per task, the row existing being what puts the student on it.
class CreateTaskStudents < ActiveRecord::Migration[7.1]
  def change
    create_table :task_students, id: :uuid do |t|
      t.references :task, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :task_students, %i[task_id student_id], unique: true
  end
end
