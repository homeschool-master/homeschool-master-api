# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Document do
  let(:teacher) { FactoryBot.create(:teacher) }

  def build_with(filename:, content_type:, size: nil)
    document = teacher.documents.build(title: 'A file')
    io = size ? StringIO.new('x' * size) : Rails.root.join("spec/fixtures/files/#{filename}").open
    document.file.attach(io: io, filename: filename, content_type: content_type)
    document
  end

  describe 'what may be uploaded' do
    it 'accepts an image' do
      expect(build_with(filename: 'receipt.png', content_type: 'image/png')).to be_valid
    end

    it 'accepts a PDF' do
      expect(build_with(filename: 'worksheet.pdf', content_type: 'application/pdf')).to be_valid
    end

    it 'accepts plain text' do
      expect(build_with(filename: 'booklist.txt', content_type: 'text/plain')).to be_valid
    end

    it 'accepts a word processor document' do
      document = build_with(filename: 'booklist.txt', size: 10,
                            content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
      expect(document).to be_valid
    end

    it 'accepts what an iPhone camera produces' do
      expect(build_with(filename: 'receipt.png', content_type: 'image/heic', size: 10)).to be_valid
    end

    # The point of an allowlist. The bytes are made up rather than checked in:
    # a real executable in a fixtures directory is something someone's virus
    # scanner quarantines, and the content type is what is being tested.
    it 'refuses an executable' do
      document = build_with(filename: 'installer.exe', content_type: 'application/x-msdownload', size: 40)

      expect(document).not_to be_valid
      expect(document.errors[:file].join).to match(/not allowed/)
    end

    it 'refuses a script' do
      expect(build_with(filename: 'booklist.txt', content_type: 'text/javascript', size: 10)).not_to be_valid
    end

    # SVG is the one people forget: a browser will run script inside it.
    it 'refuses an SVG' do
      expect(build_with(filename: 'booklist.txt', content_type: 'image/svg+xml', size: 10)).not_to be_valid
    end

    it 'refuses HTML' do
      expect(build_with(filename: 'booklist.txt', content_type: 'text/html', size: 10)).not_to be_valid
    end

    it 'refuses a document with no file at all' do
      document = teacher.documents.build(title: 'Nothing')

      expect(document).not_to be_valid
      expect(document.errors[:file].join).to match(/required/)
    end

    it 'requires a title' do
      document = build_with(filename: 'receipt.png', content_type: 'image/png')
      document.title = ''

      expect(document).not_to be_valid
    end
  end

  describe 'the size limit' do
    it 'accepts a file at the limit' do
      document = build_with(filename: 'receipt.png', content_type: 'image/png', size: described_class::MAX_BYTES)
      expect(document).to be_valid
    end

    it 'refuses a file over the limit' do
      document = build_with(filename: 'receipt.png', content_type: 'image/png',
                            size: described_class::MAX_BYTES + 1)

      expect(document).not_to be_valid
      expect(document.errors[:file].join).to match(/larger than 25 MB/)
    end
  end

  describe 'deleting' do
    it 'removes the stored file, not just the row' do
      document = FactoryBot.create(:document, teacher: teacher)
      key = document.file.blob.key
      service = document.file.blob.service

      expect(service.exist?(key)).to be(true)

      document.file.purge
      document.destroy

      expect(service.exist?(key)).to be(false)
      expect(described_class.find_by(id: document.id)).to be_nil
    end

    it 'takes its filings with it' do
      document = FactoryBot.create(:document, teacher: teacher)
      task = FactoryBot.create(:task, teacher: teacher)
      document.document_attachments.create!(attachable: task)

      expect { document.destroy }.to change(DocumentAttachment, :count).by(-1)
    end
  end

  describe 'the unattached view' do
    it 'holds a document filed against nothing' do
      document = FactoryBot.create(:document, teacher: teacher)
      expect(described_class.unattached).to include(document)
    end

    it 'drops one the moment it is filed' do
      document = FactoryBot.create(:document, teacher: teacher)
      document.document_attachments.create!(attachable: FactoryBot.create(:task, teacher: teacher))

      expect(described_class.unattached).not_to include(document)
    end
  end

  describe 'the download link' do
    # A request sets this for real; a model spec has to say it.
    before { ActiveStorage::Current.url_options = { host: 'localhost', port: 3000, protocol: 'http://' } }

    it 'expires' do
      document = FactoryBot.create(:document, teacher: teacher)
      expect(document.download_url(expires_in: 5.minutes)).to be_present
    end

    it 'is nothing at all without a file' do
      expect(described_class.new.download_url).to be_nil
    end
  end
end
