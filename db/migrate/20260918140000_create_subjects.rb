# frozen_string_literal: true

class CreateSubjects < ActiveRecord::Migration[7.1]
  def change
    create_table :subjects, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color
      t.text :description
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :subjects, :is_active

    # One name per teacher, case insensitively, and only among the subjects
    # still in play. Removal is a soft delete here, so a plain unique index
    # would let a deleted "Math" block a new one forever: the partial index
    # keeps the old row and frees the name.
    add_index :subjects,
              'teacher_id, lower(name)',
              unique: true,
              where: 'is_active',
              name: 'index_subjects_on_teacher_id_and_lower_name'
  end
end
