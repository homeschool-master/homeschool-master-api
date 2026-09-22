# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Documents', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def body
    JSON.parse(response.body)
  end

  def data
    body['data']
  end

  def upload(filename: 'receipt.png', content_type: 'image/png', size: nil)
    io = size ? StringIO.new('x' * size) : Rails.root.join("spec/fixtures/files/#{filename}").open
    blob = ActiveStorage::Blob.create_and_upload!(io: io, filename: filename, content_type: content_type)
    blob.signed_id
  end

  before do
    @teacher = FactoryBot.create(:teacher)
    sign_in(@teacher)
  end

  # The step before the upload: the browser asks for somewhere to put the file
  # and is told no before it sends anything, or told where to send it.
  describe 'POST /api/v1/documents/upload_url' do
    def ask(overrides = {})
      post upload_url_api_v1_documents_url, params: {
        filename: 'receipt.png', content_type: 'image/png', byte_size: 2048, checksum: 'abc=='
      }.merge(overrides)
    end

    it 'hands back a url and a signed id' do
      ask

      expect(response).to have_http_status(:created)
      expect(data['url']).to be_present
      expect(data['signed_id']).to be_present
      expect(data['headers'].map { |h| h['name'] }).to include('Content-Type')
    end

    it 'refuses an executable before a byte moves' do
      expect { ask(content_type: 'application/x-msdownload', filename: 'x.exe') }
        .not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a file over the size limit before a byte moves' do
      expect { ask(byte_size: Document::MAX_BYTES + 1) }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses to hand out anywhere to upload to when nobody is signed in' do
      post api_v1_auth_logout_url
      ask

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/documents' do
    it 'creates a document from a file already in storage' do
      post api_v1_documents_url, params: { title: 'Field trip receipt', file: upload }

      expect(response).to have_http_status(:created)
      expect(data['title']).to eq('Field trip receipt')
      expect(data['content_type']).to eq('image/png')
      expect(data['image']).to be(true)
    end

    it 'refuses an executable' do
      post api_v1_documents_url, params: {
        title: 'Not a receipt',
        file: upload(filename: 'installer.exe', content_type: 'application/x-msdownload', size: 40)
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Document.count).to eq(0)
    end

    # Uploads land in storage before this endpoint sees them, so a rejected one
    # has to be cleaned up or the bucket fills with files nobody can reach.
    it 'purges the stored file when it refuses the upload' do
      signed_id = upload(filename: 'installer.exe', content_type: 'application/x-msdownload', size: 40)
      blob = ActiveStorage::Blob.find_signed(signed_id)

      post api_v1_documents_url, params: { title: 'Not a receipt', file: signed_id }

      expect(blob.service.exist?(blob.key)).to be(false)
    end

    it 'refuses a file over the size limit' do
      post api_v1_documents_url, params: {
        title: 'Enormous', file: upload(size: Document::MAX_BYTES + 1)
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a document with no file' do
      post api_v1_documents_url, params: { title: 'Nothing' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'requires a title' do
      post api_v1_documents_url, params: { title: '', file: upload }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v1/documents' do
    it "lists the teacher's documents, newest first" do
      FactoryBot.create(:document, teacher: @teacher, title: 'Older', created_at: 2.days.ago)
      FactoryBot.create(:document, teacher: @teacher, title: 'Newer', created_at: 1.hour.ago)

      get api_v1_documents_url
      expect(data.map { |d| d['title'] }).to eq(%w[Newer Older])
    end

    it 'narrows to the ones filed against nothing' do
      filed = FactoryBot.create(:document, teacher: @teacher, title: 'Filed')
      FactoryBot.create(:document, teacher: @teacher, title: 'Loose')
      filed.document_attachments.create!(attachable: FactoryBot.create(:task, teacher: @teacher))

      get api_v1_documents_url, params: { unattached: 'true' }
      expect(data.map { |d| d['title'] }).to eq(['Loose'])
    end

    it 'narrows to the ones filed against one record' do
      task = FactoryBot.create(:task, teacher: @teacher)
      on_task = FactoryBot.create(:document, teacher: @teacher, title: 'On the task')
      on_task.document_attachments.create!(attachable: task)
      FactoryBot.create(:document, teacher: @teacher, title: 'Elsewhere')

      get api_v1_documents_url, params: { attachable_type: 'Task', attachable_id: task.id }
      expect(data.map { |d| d['title'] }).to eq(['On the task'])
    end

    # Nothing in a response may be usable as a key to the bytes on its own.
    it 'hands out no signed id and no blob path' do
      FactoryBot.create(:document, teacher: @teacher)
      get api_v1_documents_url

      expect(response.body).not_to include('rails/active_storage')
      expect(data.first.keys).not_to include('signed_id')
      expect(data.first['download_path']).to match(%r{/api/v1/documents/.+/download})
    end
  end

  describe 'GET /api/v1/documents/:id/download' do
    it 'redirects to a link that works' do
      document = FactoryBot.create(:document, teacher: @teacher)
      get download_api_v1_document_url(document)

      expect(response).to have_http_status(:redirect)
      expect(response.location).to be_present
    end

    # The disposition rides inside the signed link rather than on the query
    # string, so this follows the redirect and reads what actually comes back.
    it 'offers the file inline by default and as a download when asked' do
      document = FactoryBot.create(:document, teacher: @teacher)

      get download_api_v1_document_url(document)
      follow_redirect!
      expect(response.headers['Content-Disposition']).to start_with('inline')

      get download_api_v1_document_url(document), params: { download: 'true' }
      follow_redirect!
      expect(response.headers['Content-Disposition']).to start_with('attachment')
    end

    it 'serves the bytes that were uploaded' do
      document = FactoryBot.create(:document, teacher: @teacher)

      get download_api_v1_document_url(document)
      follow_redirect!

      expect(response.body.bytesize).to eq(document.file.blob.byte_size)
    end
  end

  describe 'filing a document' do
    before do
      @document = FactoryBot.create(:document, teacher: @teacher)
      @subject_record = FactoryBot.create(:subject, teacher: @teacher)
    end

    it 'files against an assignment' do
      assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @subject_record)
      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'Assignment', target_id: assignment.id
      }

      expect(response).to have_http_status(:created)
      expect(data['attachments'].first['attachable_type']).to eq('Assignment')
    end

    it 'files against a task and a calendar event at the same time' do
      task = FactoryBot.create(:task, teacher: @teacher)
      event = FactoryBot.create(:calendar_event, teacher: @teacher)

      post api_v1_document_attachments_url(@document), params: { attachable_type: 'Task', target_id: task.id }
      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'CalendarEvent', target_id: event.id
      }

      expect(data['attachments'].map { |a| a['attachable_type'] }).to contain_exactly('Task', 'CalendarEvent')
    end

    # The case the schema was shaped around: a receipt belongs to the field
    # trip on the 14th, not to every field trip the series will ever produce.
    it 'files against one occurrence of a repeating event' do
      event = FactoryBot.create(:calendar_event, teacher: @teacher)
      event.create_recurrence!(frequency: 'weekly', weekdays: [1])

      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'CalendarEvent', target_id: "#{event.id}:2026-09-14"
      }

      attachment = data['attachments'].first
      expect(attachment['occurrence_date']).to eq('2026-09-14')
      expect(attachment['target_id']).to eq("#{event.id}:2026-09-14")
    end

    it 'tells one occurrence apart from another' do
      event = FactoryBot.create(:calendar_event, teacher: @teacher)
      event.create_recurrence!(frequency: 'weekly', weekdays: [1])

      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'CalendarEvent', target_id: "#{event.id}:2026-09-14"
      }
      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'CalendarEvent', target_id: "#{event.id}:2026-09-21"
      }

      expect(data['attachments'].length).to eq(2)
    end

    it 'refuses the same filing twice' do
      task = FactoryBot.create(:task, teacher: @teacher)
      2.times do
        post api_v1_document_attachments_url(@document), params: { attachable_type: 'Task', target_id: task.id }
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(@document.document_attachments.count).to eq(1)
    end

    it 'refuses a type it does not know' do
      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'Student', target_id: SecureRandom.uuid
      }
      expect(response).to have_http_status(:not_found)
    end

    it 'detaches without deleting the document' do
      task = FactoryBot.create(:task, teacher: @teacher)
      post api_v1_document_attachments_url(@document), params: { attachable_type: 'Task', target_id: task.id }
      attachment_id = data['attachments'].first['id']

      delete api_v1_document_attachment_url(@document, attachment_id)

      expect(response).to have_http_status(:ok)
      expect(data['attachments']).to be_empty
      expect(Document.find_by(id: @document.id)).to be_present
    end

    # Filed in three places, taken off one: the other two stand.
    it 'leaves the other filings alone when one is removed' do
      task = FactoryBot.create(:task, teacher: @teacher)
      event = FactoryBot.create(:calendar_event, teacher: @teacher)
      assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @subject_record)

      post api_v1_document_attachments_url(@document), params: { attachable_type: 'Task', target_id: task.id }
      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'CalendarEvent', target_id: event.id
      }
      post api_v1_document_attachments_url(@document), params: {
        attachable_type: 'Assignment', target_id: assignment.id
      }
      first = data['attachments'].first['id']

      delete api_v1_document_attachment_url(@document, first)

      expect(data['attachments'].length).to eq(2)
    end

    it 'loses its filings when the thing it was filed against is destroyed' do
      task = FactoryBot.create(:task, teacher: @teacher)
      post api_v1_document_attachments_url(@document), params: { attachable_type: 'Task', target_id: task.id }

      task.destroy

      expect(@document.reload.document_attachments).to be_empty
      expect(Document.find_by(id: @document.id)).to be_present
    end
  end

  describe 'DELETE /api/v1/documents/:id' do
    it 'removes the row, its filings and the stored file' do
      document = FactoryBot.create(:document, teacher: @teacher)
      document.document_attachments.create!(attachable: FactoryBot.create(:task, teacher: @teacher))
      blob = document.file.blob

      perform_enqueued_jobs { delete api_v1_document_url(document) }

      expect(response).to have_http_status(:no_content)
      expect(Document.find_by(id: document.id)).to be_nil
      expect(DocumentAttachment.count).to eq(0)
      expect(blob.service.exist?(blob.key)).to be(false)
    end
  end

  # This holds children's schoolwork and family receipts. Every path is checked
  # against the owner, and a document belonging to someone else is not found
  # rather than forbidden: a 403 confirms the id exists.
  describe 'another teacher' do
    before do
      @other = FactoryBot.create(:teacher)
      @theirs = FactoryBot.create(:document, teacher: @other, title: 'Not yours')
    end

    it 'cannot see it in the list' do
      get api_v1_documents_url
      expect(data.map { |d| d['title'] }).not_to include('Not yours')
    end

    it 'cannot fetch it by id' do
      get api_v1_document_url(@theirs)
      expect(response).to have_http_status(:not_found)
    end

    it 'cannot download it' do
      get download_api_v1_document_url(@theirs)
      expect(response).to have_http_status(:not_found)
    end

    it 'cannot rename it' do
      patch api_v1_document_url(@theirs), params: { title: 'Mine now' }

      expect(response).to have_http_status(:not_found)
      expect(@theirs.reload.title).to eq('Not yours')
    end

    it 'cannot delete it' do
      delete api_v1_document_url(@theirs)

      expect(response).to have_http_status(:not_found)
      expect(Document.find_by(id: @theirs.id)).to be_present
    end

    it 'cannot file it against anything' do
      task = FactoryBot.create(:task, teacher: @teacher)
      post api_v1_document_attachments_url(@theirs), params: { attachable_type: 'Task', target_id: task.id }

      expect(response).to have_http_status(:not_found)
      expect(@theirs.reload.document_attachments).to be_empty
    end

    it "cannot file its own document against another teacher's record" do
      mine = FactoryBot.create(:document, teacher: @teacher)
      their_task = FactoryBot.create(:task, teacher: @other)

      post api_v1_document_attachments_url(mine), params: { attachable_type: 'Task', target_id: their_task.id }

      expect(response).to have_http_status(:not_found)
      expect(mine.reload.document_attachments).to be_empty
    end

    it 'cannot reach it through the attachment listing' do
      their_task = FactoryBot.create(:task, teacher: @other)
      @theirs.document_attachments.create!(attachable: their_task)

      get api_v1_documents_url, params: { attachable_type: 'Task', attachable_id: their_task.id }
      expect(data).to be_empty
    end
  end

  context 'when not authenticated' do
    it 'refuses the list' do
      post api_v1_auth_logout_url
      get api_v1_documents_url
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
