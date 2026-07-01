# frozen_string_literal: true

class CreateStudents < ActiveRecord::Migration[7.1]
  def change
    create_table :students, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :grade_level
      t.string :color
      t.string :profile_image_url
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :students, :is_active
  end
end
