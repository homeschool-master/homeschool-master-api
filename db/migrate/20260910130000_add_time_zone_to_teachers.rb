# frozen_string_literal: true

class AddTimeZoneToTeachers < ActiveRecord::Migration[7.1]
  def change
    add_column :teachers, :time_zone, :string
  end
end
