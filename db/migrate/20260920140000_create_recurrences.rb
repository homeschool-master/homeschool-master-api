# frozen_string_literal: true

# A repeat rule, stored once against whatever repeats. Polymorphic because
# events and tasks repeat on the same rules and should not grow two
# implementations of them: the owner supplies the anchor date, the rule
# supplies the pattern.
#
# Occurrences are not stored. They are computed for whatever window is asked
# for, so a weekly event is one row rather than one row a week forever.
class CreateRecurrences < ActiveRecord::Migration[7.1]
  def change
    create_table :recurrences, id: :uuid do |t|
      t.references :recurrable, type: :uuid, polymorphic: true, null: false
      t.string :frequency, null: false
      # Weekly only, 0 for Sunday through 6 for Saturday. Several at once, so
      # "every Tuesday and Thursday" is one series rather than two.
      t.integer :weekdays, array: true, default: [], null: false
      # Monthly only: the same date each month, or the same weekday position.
      t.string :monthly_anchor
      # The last day the series can produce an occurrence. Null never ends.
      t.date :until_date

      t.timestamps
    end

    add_index :recurrences, %i[recurrable_type recurrable_id], unique: true,
                            name: 'index_recurrences_on_owner'
  end
end
