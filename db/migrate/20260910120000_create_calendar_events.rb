# frozen_string_literal: true

class CreateCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_events, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :notes
      t.string :location
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.boolean :all_day, null: false, default: false

      t.timestamps
    end

    add_index :calendar_events, %i[teacher_id start_time]
  end
end
