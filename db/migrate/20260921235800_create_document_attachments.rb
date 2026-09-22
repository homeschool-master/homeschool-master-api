# frozen_string_literal: true

# What a document is filed against.
#
# One row per thing a document is attached to, so one document can sit on an
# assignment, a task and a calendar event at once: the receipt for a field
# trip is also the receipt on the expense side of the same outing. A join
# table rather than columns on documents, because "in any combination" is a
# list and a list is rows.
#
# Polymorphic rather than three tables. The three attachables behave
# identically from the document's side, and a fourth later is a string in a
# validation rather than a migration.
#
# occurrence_date is the part worth reading twice. A repeating event or task
# has no row per occurrence: an occurrence is named by its series and a date,
# "<uuid>:<date>". A receipt almost always belongs to one occurrence, the field
# trip on the 14th, not to every field trip the series will ever produce. So:
#
#   occurrence_date NULL   attached to the record itself: an ordinary event,
#                          or a whole series
#   occurrence_date set    attached to that one occurrence of that series
#
# This is the same shape task_completions already uses to record a tick against
# one occurrence, which is the precedent worth matching: the codebase has
# answered "how do I say something about one occurrence" once already.
class CreateDocumentAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :document_attachments, id: :uuid do |t|
      t.references :document, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :attachable_type, null: false
      t.uuid :attachable_id, null: false
      t.date :occurrence_date
      t.timestamps
    end

    add_index :document_attachments, %i[attachable_type attachable_id]

    # Two partial indexes rather than one. Postgres treats NULLs as distinct in
    # a unique index, so a single index over the four columns would happily
    # allow the same document to be attached to the same event twice with no
    # occurrence date.
    add_index :document_attachments, %i[document_id attachable_type attachable_id],
              unique: true, where: 'occurrence_date IS NULL',
              name: 'index_document_attachments_on_whole_record'
    add_index :document_attachments, %i[document_id attachable_type attachable_id occurrence_date],
              unique: true, where: 'occurrence_date IS NOT NULL',
              name: 'index_document_attachments_on_occurrence'
  end
end
