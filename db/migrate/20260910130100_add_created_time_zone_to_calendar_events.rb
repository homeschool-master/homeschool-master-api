# frozen_string_literal: true

class AddCreatedTimeZoneToCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :calendar_events, :created_time_zone, :string
  end
end
