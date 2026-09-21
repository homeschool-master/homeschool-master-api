# frozen_string_literal: true

# One subject's line on a report card.
#
# The snapshot lives here. An issued card renders from these rows alone and
# never touches an assignment, which is what makes it immune to a later
# rescore.
#
# assignments is the work each figure was summed from, captured whole rather
# than as a count. A card that kept only the percentage could not show a reader
# what it was based on, and recomputing the list later would defeat the point
# of freezing the figure. It is jsonb rather than a third table because nothing
# queries inside a frozen document: it is written once, read back as a whole,
# and its shape is exactly what ProgressEntrySerializer already produces for
# the gradebook, so the stored rows and the live ones cannot drift apart.
#
# subject_name is denormalized on purpose. Renaming a subject, or removing it,
# must not change a card that was already handed over.
class CreateReportCardEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :report_card_entries, id: :uuid do |t|
      t.references :report_card, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      # Nullified rather than cascaded: a removed subject leaves the line on
      # the card, which still reads because the name is held here too.
      t.references :subject, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :subject_name, null: false

      # The calculated figures, frozen at issue and null while a draft.
      t.decimal :percentage, precision: 5, scale: 2
      t.string :letter
      t.decimal :points_earned, precision: 10, scale: 2
      t.decimal :points_possible, precision: 10, scale: 2
      t.integer :assigned_count
      t.integer :graded_count
      t.integer :ungraded_count
      t.jsonb :assignments

      # What the teacher issued instead, and why. The calculated pair above
      # survives, so the card can show both.
      t.string :override_letter
      t.text :override_reason

      t.text :comments
      # Alphabetical at capture, held so a card keeps the order it was issued
      # in even if a subject is renamed afterwards.
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :report_card_entries, %i[report_card_id subject_id], unique: true
  end
end
