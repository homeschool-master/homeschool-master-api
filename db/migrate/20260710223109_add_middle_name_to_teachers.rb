# frozen_string_literal: true

class AddMiddleNameToTeachers < ActiveRecord::Migration[7.1]
  def change
    add_column :teachers, :middle_name, :string
  end
end