# frozen_string_literal: true

class CreateEventAttendees < ActiveRecord::Migration[7.1]
  def change
    create_table :event_attendees, id: :uuid do |t|
      t.references :calendar_event, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :student, type: :uuid, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :event_attendees, %i[calendar_event_id student_id], unique: true
  end
end
