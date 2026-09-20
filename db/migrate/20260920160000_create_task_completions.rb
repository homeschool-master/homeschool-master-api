# frozen_string_literal: true

# One ticked occurrence of a repeating task.
#
# A task that does not repeat keeps its completion in its own completed_at
# column, which is unchanged. A series cannot: one row stands for every
# occurrence, so setting that column would tick next week along with this one.
#
# Deliberately not a recurrence_exception. An exception means the occurrence
# does not follow the rule, and a completed occurrence still does: it is on its
# date, with the series title, and a later edit to the series should still
# reach it. Filing it there would also collide with replacement_id being null
# already meaning deleted.
class CreateTaskCompletions < ActiveRecord::Migration[7.1]
  def change
    create_table :task_completions, id: :uuid do |t|
      t.references :task, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      # The local date of the occurrence, which is how a client names one: a
      # series has no row per occurrence to point at.
      t.date :occurrence_date, null: false
      # When it was ticked. Not null: the row existing is the completion, so
      # unticking deletes it rather than nulling this.
      t.datetime :completed_at, null: false

      t.timestamps
    end

    add_index :task_completions, %i[task_id occurrence_date], unique: true
  end
end
