# frozen_string_literal: true

# A file a teacher has uploaded: a receipt, a worksheet, a photo of finished
# work, a curriculum PDF.
#
# The row is the document; the bytes hang off it as an Active Storage
# attachment. A title is the teacher's own, because a filename off a phone is
# IMG_4821.HEIC and says nothing about what the thing is.
#
# Deliberately thin. Later slices read receipts and pull out a date, a vendor
# and an amount, and those become nullable columns here: a flat table owned by
# one teacher takes them without rearranging anything.
class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents, id: :uuid do |t|
      t.references :teacher, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.timestamps
    end

    add_index :documents, %i[teacher_id created_at]
  end
end
