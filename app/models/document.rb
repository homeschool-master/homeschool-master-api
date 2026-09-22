# frozen_string_literal: true

# A file a teacher has uploaded, and what it is filed against.
#
# The bytes are an Active Storage attachment. They reach storage before this
# record exists, because uploads go straight from the browser to the bucket
# rather than through Rails, so everything here validates a blob that is
# already sitting there: a rejected upload is purged rather than refused.
class Document < ApplicationRecord
  # What a teacher can upload.
  #
  # An allowlist, not a blocklist: a blocklist is a guess about what is
  # dangerous and is wrong the moment a new type appears. Images and PDFs are
  # the two that matter, because a receipt or a worksheet is photographed or
  # scanned. The office formats are here because curricula arrive as .docx and
  # spreadsheets are how families track a booklist.
  #
  # Nothing executable, and nothing that can carry a script: no .exe, no .js,
  # no .html, no .svg. SVG is the one people forget, and it is a script
  # container that a browser will happily run.
  IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif image/heic image/heif].freeze
  DOCUMENT_TYPES = %w[
    application/pdf
    text/plain
    text/csv
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.oasis.opendocument.text
    application/vnd.oasis.opendocument.spreadsheet
  ].freeze
  ALLOWED_TYPES = (IMAGE_TYPES + DOCUMENT_TYPES).freeze

  # 25 MB. A scanned multi page worksheet runs to ten or twenty; a phone photo
  # arrives shrunk by the browser before it is uploaded, so images land far
  # under this. Past 25 the thing being uploaded is usually a video, which is
  # not what this is for and is the one thing that makes storage costs run.
  MAX_BYTES = 25.megabytes

  # Associations
  belongs_to :teacher
  has_one_attached :file
  has_many :document_attachments, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validate :file_is_attached
  validate :file_is_an_allowed_type
  validate :file_is_within_the_size_limit

  # Scopes
  scope :newest_first, -> { order(created_at: :desc) }
  # Uploaded but not filed against anything yet: upload now, file later.
  scope :unattached, -> { where.missing(:document_attachments) }

  def attached_to_anything?
    document_attachments.any?
  end

  def content_type
    file.attached? ? file.blob.content_type : nil
  end

  def byte_size
    file.attached? ? file.blob.byte_size : nil
  end

  def filename
    file.attached? ? file.blob.filename.to_s : nil
  end

  def image?
    IMAGE_TYPES.include?(content_type)
  end

  # A short lived signed link to the bytes, minted per request.
  #
  # Never a public URL and never a permanent one: the bucket blocks public
  # access, and a link that leaks is useless within minutes. Callers reach this
  # only after the request has been checked against the owning teacher.
  def download_url(disposition: :inline, expires_in: 5.minutes)
    return nil unless file.attached?

    file.blob.url(expires_in: expires_in, disposition: disposition,
                  filename: file.blob.filename, content_type: file.blob.content_type)
  end

  private

  def file_is_attached
    errors.add(:file, 'is required') unless file.attached?
  end

  def file_is_an_allowed_type
    return unless file.attached?
    return if ALLOWED_TYPES.include?(file.blob.content_type)

    errors.add(:file, "type #{file.blob.content_type} is not allowed")
  end

  def file_is_within_the_size_limit
    return unless file.attached?
    return if file.blob.byte_size <= MAX_BYTES

    errors.add(:file, "is larger than #{MAX_BYTES / 1.megabyte} MB")
  end
end
