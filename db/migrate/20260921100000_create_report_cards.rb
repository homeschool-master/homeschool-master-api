# frozen_string_literal: true

# A saved copy of one student's grades for a period, the way a printed report
# card sits in a folder.
#
# The point of the table is that an issued card keeps saying what it said. A
# parent hands one to a co-op or an evaluator, then fixes a marking error three
# weeks later, and the card that was handed over must not quietly change. So an
# issued card carries its own figures rather than pointing at the grades they
# came from.
#
# Column names follow the implementation guide rather than
# database-architecture.md, which described the same fields as start_date,
# end_date and published_at. period_start and period_end match the vocabulary
# the rest of the app uses for a span, and issued_at follows the same shape as
# completed_at and graded_at: a nullable timestamp that both records when
# something happened and answers whether it has. There is no separate status
# column for the same reason those tables have none.
#
# Three columns the architecture doc asked for are deliberately absent:
# period_type, because a label like "quarterly" that constrains nothing is
# decoration when the period is already two dates and the title says what it
# is; grading_system, because the app has exactly one scale and a column
# offering three would be a promise nothing keeps; and the three value status,
# because "finalized" and "published" are the same event here.
class CreateReportCards < ActiveRecord::Migration[7.1]
  def change
    create_table :report_cards, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: true
      t.references :student, type: :uuid, null: false, foreign_key: { on_delete: :cascade }

      # Every version of one card shares a group. The highest version in a
      # group is the one that stands; the rest stay readable, which is what
      # makes "the old one is still intact" true rather than a promise.
      t.uuid :group_id, null: false
      t.integer :version, null: false, default: 1

      t.string :title, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.text :comments

      # The overall figure as calculated, frozen at issue. Null on a draft,
      # which computes live instead.
      t.decimal :overall_percentage, precision: 5, scale: 2
      t.string :overall_letter

      # What the teacher issued instead, when she weighs something the numbers
      # do not show. The calculated pair above is kept either way, so an
      # override is visible rather than a quiet replacement.
      t.string :overall_override_letter
      t.text :overall_override_reason

      t.datetime :issued_at
      t.timestamps
    end

    add_index :report_cards, %i[group_id version], unique: true
    add_index :report_cards, %i[student_id period_start]
  end
end
