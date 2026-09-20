# frozen_string_literal: true

# Whose job a task is, which naming students cannot express on its own.
# "Export report cards" names Scarlett and is the teacher's work; "Finish the
# science fair project" names her and is hers. Both carry the same student, so
# the difference has to be recorded separately.
#
# Existing rows are the teacher's own: tasks were teacher only until now, so
# that is what they have always meant rather than a default chosen for them.
class AddOwnedByToTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :tasks, :owned_by, :string, null: false, default: 'teacher'
    add_index :tasks, %i[teacher_id owned_by]
  end
end
