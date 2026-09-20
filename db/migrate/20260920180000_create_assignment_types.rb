# frozen_string_literal: true

# What kind of work an assignment is, and how much that kind counts by default.
#
# Per teacher rather than global, including the three built in ones. The whole
# point of the feature is that a teacher sets her own default weight for Tests,
# and a shared row could only hold one family's answer. Built in rows are
# created for every teacher and marked so, which is what stops them being
# renamed or removed: they are the vocabulary everyone starts from.
class CreateAssignmentTypes < ActiveRecord::Migration[7.1]
  def up
    create_table :assignment_types, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      # Every type starts at 1, built in and custom alike, so grades behave
      # exactly as they did before types existed until a teacher says otherwise.
      t.decimal :default_weight, precision: 10, scale: 2, default: '1.0', null: false
      t.boolean :is_built_in, default: false, null: false
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end

    # The same rule subjects have: one name per teacher, case insensitive, and
    # only among the types still in play, so a removed name can be used again.
    add_index :assignment_types, 'teacher_id, lower(name)',
              unique: true, where: 'is_active', name: 'index_assignment_types_on_teacher_id_and_lower_name'

    seed_built_in_types
  end

  def down
    drop_table :assignment_types
  end

  private

  # Written in SQL rather than through the model, so this migration keeps
  # working if the model's validations change later.
  def seed_built_in_types
    execute(<<~SQL.squish)
      INSERT INTO assignment_types (id, teacher_id, name, default_weight, is_built_in, is_active, created_at, updated_at)
      SELECT gen_random_uuid(), teachers.id, names.name, 1.0, true, true, NOW(), NOW()
      FROM teachers
      CROSS JOIN (VALUES ('Assignment'), ('Quiz'), ('Test')) AS names(name)
    SQL
  end
end
