# frozen_string_literal: true

module Api
  module V1
    # A teacher's uploaded files.
    #
    # Every action is scoped to the signed in teacher, including the one that
    # serves the bytes: this holds children's schoolwork and family receipts,
    # so another teacher's document is not found rather than forbidden, and
    # nothing hands out a link that outlives the request by more than minutes.
    class DocumentsController < BaseController
      before_action :set_document, only: %i[show update destroy download]

      # GET /api/v1/documents?unattached=true&attachable_type=&attachable_id=
      def index
        render_success(filtered.map { |document| DocumentSerializer.render(document) })
      end

      # GET /api/v1/documents/:id
      def show
        render_success(DocumentSerializer.render(@document))
      end

      # POST /api/v1/documents/upload_url
      #
      # The browser sends the bytes straight to storage and then tells us about
      # them. A 25MB upload through one small dyno would sit inside Heroku's 30
      # second request limit with nothing to show for it, and the dyno has
      # better things to do than relay files.
      #
      # This is the step in between: it asks who is uploading, refuses a type
      # or a size we will not keep before a single byte moves, and hands back a
      # URL good for that one file. Active Storage draws an endpoint that does
      # the same thing without asking who is calling, which is why that one is
      # turned off in production.
      def upload_url
        refusal = upload_refusal
        return render_error(refusal, code: 'VALIDATION_ERROR', status: :unprocessable_entity) if refusal

        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: upload_params[:filename],
          byte_size: upload_params[:byte_size].to_i,
          checksum: upload_params[:checksum],
          content_type: upload_params[:content_type]
        )

        render_created(upload_instructions(blob))
      end

      # POST /api/v1/documents
      #
      # The bytes are already in storage: the browser put them there directly
      # and this receives the signed id that came back. So a file that fails
      # validation is purged rather than simply refused, otherwise every
      # rejected upload would sit in the bucket forever.
      def create
        document = current_teacher.documents.build(title: document_params[:title])
        document.file.attach(document_params[:file])
        return render_created(DocumentSerializer.render(document)) if document.save

        refuse(document)
      end

      # PATCH /api/v1/documents/:id
      # The title only. Replacing the file is a new document: a receipt that
      # changed is a different receipt.
      def update
        if @document.update(title: document_params[:title])
          render_success(DocumentSerializer.render(@document))
        else
          render_validation_errors(@document)
        end
      end

      # DELETE /api/v1/documents/:id
      #
      # Destroys the record, its attachment rows, and the bytes. purge_later
      # rather than purge so a slow bucket cannot hold up the response, and it
      # is queued before the row goes so the blob cannot be orphaned.
      def destroy
        @document.file.purge_later if @document.file.attached?
        @document.destroy
        render_no_content
      end

      # GET /api/v1/documents/:id/download
      #
      # The only way to the bytes. Ownership is checked by set_document, then
      # this redirects to a signed URL that expires in five minutes.
      def download
        url = @document.download_url(disposition: disposition)
        return render_not_found('Document') if url.nil?

        redirect_to url, allow_other_host: true
      end

      private

      def filtered
        documents = current_teacher.documents.includes(:document_attachments).newest_first
        documents = documents.unattached if params[:unattached] == 'true'
        return documents if params[:attachable_type].blank? || params[:attachable_id].blank?

        documents.where(id: attached_document_ids)
      end

      # Documents filed against one thing. An occurrence date narrows it to that
      # occurrence; without one it is the record itself.
      def attached_document_ids
        scope = DocumentAttachment.for_record(params[:attachable_type], params[:attachable_id])
        scope = if params[:occurrence_date].present?
                  scope.where(occurrence_date: params[:occurrence_date])
                else
                  scope.where(occurrence_date: nil)
                end
        scope.select(:document_id)
      end

      # The same two rules the model enforces, applied before the upload rather
      # than after it: an executable or a file too large to keep is refused
      # while it is still on her phone.
      def upload_refusal
        return 'That kind of file cannot be uploaded' unless
          Document::ALLOWED_TYPES.include?(upload_params[:content_type])
        return "Files must be under #{Document::MAX_BYTES / 1.megabyte}MB" if
          upload_params[:byte_size].to_i > Document::MAX_BYTES

        nil
      end

      # The headers are a list of name and value rather than a hash because
      # responses are camelised on request, and Content-Type is a header name,
      # not a field of ours to rename.
      def upload_instructions(blob)
        {
          signed_id: blob.signed_id,
          url: blob.service_url_for_direct_upload,
          headers: blob.service_headers_for_direct_upload.map { |name, value| { name: name, value: value } }
        }
      end

      def upload_params
        params.permit(:filename, :byte_size, :checksum, :content_type)
      end

      # A refused upload has to take its bytes with it, or every rejected file
      # sits in the bucket with no row pointing at it.
      def refuse(document)
        document.file.purge if document.file.attached?
        render_validation_errors(document)
      end

      def set_document
        @document = current_teacher.documents.find_by(id: params[:id])
        render_not_found('Document') if @document.nil?
      end

      def disposition
        params[:download] == 'true' ? :attachment : :inline
      end

      def document_params
        params.permit(:title, :file)
      end
    end
  end
end
