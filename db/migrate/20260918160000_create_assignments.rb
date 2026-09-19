# frozen_string_literal: true

class CreateAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :assignments, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: true
      # Required: an assignment is work in a subject, and the subject is what
      # the report card groups by. Subjects soft delete, so this never dangles.
      t.references :subject, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :due_date
      # What the work is out of. Required and positive, because every
      # percentage in the app divides by it.
      t.decimal :points_possible, precision: 10, scale: 2, null: false, default: 100
      # How much it counts relative to other work in the same subject. 1 is
      # ordinary, 3 is an exam worth three of them, 0 is practice that does not
      # count at all.
      t.decimal :weight, precision: 10, scale: 2, null: false, default: 1

      t.timestamps
    end

    add_index :assignments, %i[teacher_id due_date]
  end
end
