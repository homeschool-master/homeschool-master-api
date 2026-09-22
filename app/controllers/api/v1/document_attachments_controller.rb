# frozen_string_literal: true

module Api
  module V1
    # Filing a document against an assignment, a task or a calendar event, and
    # taking it off again.
    #
    # Detaching removes the filing and leaves the document in the library: a
    # receipt taken off one event is still a receipt. Deleting the document
    # itself is a different action, on the documents controller.
    class DocumentAttachmentsController < BaseController
      before_action :set_document

      # POST /api/v1/documents/:document_id/attachments
      #
      # target_id is either a bare uuid or an occurrence id, "<uuid>:<date>",
      # which is the same id the client already holds for a row it is looking
      # at. Splitting it here means the caller never has to know which kind it
      # has.
      def create
        record_id, occurrence_date = TaskSerializer.parse_id(params[:target_id])
        attachable = find_attachable(params[:attachable_type], record_id)
        return render_not_found('Record') if attachable.nil?

        attachment = @document.document_attachments.build(
          attachable: attachable, occurrence_date: occurrence_date
        )
        return render_already_attached unless attachment.save

        render_created(DocumentSerializer.render(@document.reload))
      end

      # DELETE /api/v1/documents/:document_id/attachments/:id
      def destroy
        attachment = @document.document_attachments.find_by(id: params[:id])
        return render_not_found('Attachment') if attachment.nil?

        attachment.destroy
        render_success(DocumentSerializer.render(@document.reload))
      end

      private

      def set_document
        @document = current_teacher.documents.find_by(id: params[:document_id])
        render_not_found('Document') if @document.nil?
      end

      # Scoped through the teacher on every branch, so a valid id belonging to
      # someone else is not found rather than quietly filed against.
      def find_attachable(type, id)
        return nil unless DocumentAttachment::ATTACHABLE_TYPES.include?(type)

        case type
        when 'Assignment' then current_teacher.assignments.find_by(id: id)
        when 'Task' then current_teacher.tasks.find_by(id: id)
        when 'CalendarEvent' then current_teacher.calendar_events.find_by(id: id)
        end
      end

      def render_already_attached
        render_error('This document is already filed there.', code: 'VALIDATION_ERROR',
                                                              status: :unprocessable_entity)
      end
    end
  end
end
