# frozen_string_literal: true

# Gives every assignment a type, and records whether its weight is the type's
# default or a number the teacher chose for this one piece of work.
#
# weight_overridden is the whole reason a default can be changed safely. An
# inherited weight is a copy of the default, which is what lets the three apply
# modes decide when to push a new default onto existing work. An overridden one
# is a decision about this assignment, and no later change to a default may
# touch it.
class AddTypeAndWeightSourceToAssignments < ActiveRecord::Migration[7.1]
  def up
    add_column :assignments, :assignment_type_id, :uuid
    add_column :assignments, :weight_overridden, :boolean, default: false, null: false

    backfill_types
    backfill_weight_source

    change_column_null :assignments, :assignment_type_id, false
    add_foreign_key :assignments, :assignment_types
    add_index :assignments, :assignment_type_id
  end

  def down
    remove_column :assignments, :weight_overridden
    remove_column :assignments, :assignment_type_id
  end

  private

  # Everything that existed before types did is an Assignment: it is the
  # ordinary case and the one whose default weight of 1 matches what those rows
  # already carry.
  def backfill_types
    execute(<<~SQL.squish)
      UPDATE assignments
      SET assignment_type_id = assignment_types.id
      FROM assignment_types
      WHERE assignment_types.teacher_id = assignments.teacher_id
        AND assignment_types.name = 'Assignment'
        AND assignment_types.is_built_in
    SQL
  end

  # A weight that is not 1 was typed by a teacher, because there were no
  # defaults to inherit it from. Marking those as overridden keeps a choice she
  # already made from being swept away by the first default change she makes.
  def backfill_weight_source
    execute('UPDATE assignments SET weight_overridden = true WHERE weight <> 1.0')
  end
end
