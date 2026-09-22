# frozen_string_literal: true

class DocumentSerializer
  def self.render(document, attachments: true)
    new(document, attachments: attachments).to_h
  end

  def initialize(document, attachments: true)
    @document = document
    @attachments = attachments
  end

  def to_h
    base.merge(@attachments ? { attachments: attachment_rows } : {})
  end

  private

  # No Active Storage signed id and no rails blob path anywhere in here.
  #
  # Those are bearer tokens: anyone holding one can fetch the bytes, and they
  # are not scoped to a teacher. The only way to the file is download_path,
  # which checks the owner first and then mints a link that dies in minutes.
  def base # rubocop:disable Metrics/MethodLength
    {
      id: @document.id,
      teacher_id: @document.teacher_id,
      title: @document.title,
      filename: @document.filename,
      content_type: @document.content_type,
      byte_size: @document.byte_size,
      image: @document.image?,
      download_path: "/api/v1/documents/#{@document.id}/download",
      created_at: @document.created_at
    }
  end

  def attachment_rows
    @document.document_attachments.map do |attachment|
      {
        id: attachment.id,
        attachable_type: attachment.attachable_type,
        attachable_id: attachment.attachable_id,
        occurrence_date: attachment.occurrence_date,
        # The id the client uses for an occurrence, rebuilt so the web app can
        # match an attachment against a row it is already showing.
        target_id: target_id(attachment),
        label: label_for(attachment)
      }
    end
  end

  def target_id(attachment)
    return attachment.attachable_id if attachment.occurrence_date.blank?

    "#{attachment.attachable_id}:#{attachment.occurrence_date}"
  end

  # What the thing is called, so the library can say where a document is filed
  # without the client fetching three more collections to find out.
  def label_for(attachment)
    attachment.attachable&.title
  end
end
