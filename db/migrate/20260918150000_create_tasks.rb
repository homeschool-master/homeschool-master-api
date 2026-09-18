# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :due_date
      # Completion is an event, so it is stored as the moment it happened
      # rather than as a flag. Null means not done. See the model.
      t.datetime :completed_at

      t.timestamps
    end

    # The dashboard asks one question: what is still open, soonest first.
    add_index :tasks, %i[teacher_id due_date]
    add_index :tasks, :completed_at
  end
end
