# frozen_string_literal: true

class Teacher < ApplicationRecord
  has_secure_password

  # Associations (will be added later)
  has_many :students, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :report_cards, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :subjects, dependent: :destroy
  has_many :lesson_plans, dependent: :destroy
  has_many :expense_categories, dependent: :destroy

  # Validations
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :nickname, length: { maximum: 100 }, allow_blank: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true,
                       length: { minimum: 8 },
                       if: :password_required?
  validates :phone, length: { maximum: 20 }, allow_blank: true

  # Callbacks
  before_save :downcase_email
  before_create :generate_email_verification_token

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :verified, -> { where.not(email_verified_at: nil) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    nickname.presence || full_name
  end

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(
      email_verified_at: Time.current,
      email_verification_token: nil
    )
  end

  def generate_password_reset_token!
    update!(
      password_reset_token: SecureRandom.urlsafe_base64(32),
      password_reset_sent_at: Time.current
    )
  end

  def password_reset_token_valid?
    return false if password_reset_token.blank? || password_reset_sent_at.blank?

    password_reset_sent_at > 2.hours.ago
  end

  def clear_password_reset_token!
    update!(
      password_reset_token: nil,
      password_reset_sent_at: nil
    )
  end

  # Class methods
  def self.find_by_email(email)
    find_by(email: email.downcase)
  end

  private

  def downcase_email
    self.email = email.downcase
  end

  def generate_email_verification_token
    self.email_verification_token = SecureRandom.urlsafe_base64(32)
  end

  def password_required?
    new_record? || password.present?
  end
end
