# frozen_string_literal: true

class Teacher < ApplicationRecord
  # Everything about proving control of an inbox: the verification, password
  # reset and email change tokens, and their expiry windows.
  include OneTimeTokens

  has_secure_password

  # Used when a teacher has no zone of their own. The column stays nullable and
  # existing rows are not backfilled: this fallback covers them.
  DEFAULT_TIME_ZONE = 'America/New_York'

  # Associations
  has_many :refresh_tokens, dependent: :destroy
  has_many :students, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :subjects, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :assignment_types, dependent: :destroy
  has_many :report_cards, dependent: :destroy
  has_many :documents, dependent: :destroy

  # Validations
  validates :first_name, presence: { message: "can't be blank" }, length: { maximum: 100 }
  validates :middle_name, length: { maximum: 100 }, allow_blank: true
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :nickname, length: { maximum: 100 }, allow_blank: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :phone, length: { maximum: 20 }, allow_blank: true
  validates :time_zone, iana_time_zone: true

  # Callbacks
  before_save :downcase_email
  # A new account can set work on its first day rather than having to invent a
  # vocabulary before it can grade anything.
  after_create -> { AssignmentType.create_built_ins_for(self) }
  before_save :nullify_blank_middle_name

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :verified, -> { where.not(email_verified_at: nil) }

  # Instance methods

  # The zone to use when rendering times for this teacher with no client to ask,
  # such as reminder emails and exports. Never nil, so callers do not branch.
  def effective_time_zone
    time_zone.presence || DEFAULT_TIME_ZONE
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    nickname.presence || full_name
  end

  # Class methods

  # Finds teacher regardless of email casing. Usefull when resetting pw and email, etc
  def self.find_by_email(email)
    find_by(email: email.downcase)
  end

  private

  def downcase_email
    self.email = email&.downcase
  end

  def password_required?
    new_record? || password.present?
  end

  def nullify_blank_middle_name
    self.middle_name = nil if middle_name.blank?
  end
end
