# frozen_string_literal: true

class CreateAssignmentGrades < ActiveRecord::Migration[7.1]
  def change
    create_table :assignment_grades, id: :uuid do |t|
      t.references :assignment, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      # Null means assigned but not graded yet, which is not the same as zero
      # and is excluded from every calculation. An explicit 0 is a real score.
      t.decimal :points_earned, precision: 10, scale: 2
      t.text :notes
      t.datetime :graded_at

      t.timestamps
    end

    # One row per student per assignment: the row is both the assignment of the
    # work and the score for it.
    add_index :assignment_grades, %i[assignment_id student_id], unique: true
  end
end
