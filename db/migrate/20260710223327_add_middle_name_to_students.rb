# frozen_string_literal: true

class AddMiddleNameToStudents < ActiveRecord::Migration[7.1]
  def change
    add_column :students, :middle_name, :string
  end
end