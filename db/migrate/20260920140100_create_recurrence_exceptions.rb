# frozen_string_literal: true

# One occurrence of a series that does not follow the rule.
#
# replacement_id null means the occurrence was deleted. Set, it names the
# standalone row that stands in for it: editing one occurrence detaches it into
# an ordinary event or task, which keeps its attendees, its serializer and its
# update path rather than inventing a parallel set of them.
class CreateRecurrenceExceptions < ActiveRecord::Migration[7.1]
  def change
    create_table :recurrence_exceptions, id: :uuid do |t|
      t.references :recurrence, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      # The local date of the occurrence being excepted, which is how the
      # client names one: a series has no row per occurrence to point at.
      t.date :occurrence_date, null: false
      # The replacement is the same kind as the series owner, so its type is
      # already known and needs no column of its own.
      t.uuid :replacement_id

      t.timestamps
    end

    add_index :recurrence_exceptions, %i[recurrence_id occurrence_date], unique: true,
                                      name: 'index_recurrence_exceptions_on_series_and_date'
  end
end
