# frozen_string_literal: true

# Remembers that a mark was entered as a letter rather than typed as a number.
#
# points_earned stays the only number anything calculates with, so every
# average, roll up and report is untouched by this column. What it adds is
# provenance: reopening a grade shows the A she entered rather than the 95 it
# became, and a letter key that changes later does not silently rewrite marks
# already recorded, because the score was stored, not derived on read.
class AddEnteredLetterToAssignmentGrades < ActiveRecord::Migration[7.1]
  def change
    add_column :assignment_grades, :entered_letter, :string
  end
end
