# frozen_string_literal: true

# The short lived tokens a teacher is sent by email, and their lifecycles.
#
# Three of them, and they are one idea rather than three: a random string is
# written to the record with a timestamp, sent to an inbox, checked against an
# expiry when it comes back, and cleared once it has been used. Email
# verification, password reset and email change all work that way and differ
# only in what they unlock.
#
# Extracted from Teacher because that is where they were crowding out the
# things a teacher actually is: a name, a zone, a roster and the work hanging
# off it. Every one of these methods is about proving control of an inbox, and
# none of them is about a teacher, so they belong together and elsewhere.
module OneTimeTokens
  extend ActiveSupport::Concern

  # How long a token is good for. Both windows were already an hour: naming
  # them says so once rather than twice, and the two can diverge later without
  # anyone having to find both call sites.
  PASSWORD_RESET_WINDOW = 1.hour
  EMAIL_CHANGE_WINDOW = 1.hour
  TOKEN_BYTES = 32

  included do
    before_create :generate_email_verification_token
  end

  # Email verification

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current, email_verification_token: nil)
  end

  # Password reset

  def generate_password_reset_token!
    update!(
      password_reset_token: self.class.new_token,
      password_reset_sent_at: Time.current
    )
  end

  def password_reset_token_valid?
    return false if password_reset_token.blank? || password_reset_sent_at.blank?

    password_reset_sent_at > PASSWORD_RESET_WINDOW.ago
  end

  def clear_password_reset_token!
    update!(password_reset_token: nil, password_reset_sent_at: nil)
  end

  # Email change

  def generate_email_change_token!(new_email)
    update!(
      pending_email: new_email,
      email_change_token: self.class.new_token,
      email_change_sent_at: Time.current
    )
  end

  def email_change_token_valid?
    return false if email_change_token.blank? || email_change_sent_at.blank?

    email_change_sent_at > EMAIL_CHANGE_WINDOW.ago
  end

  # Moves the pending address onto the record and counts it as verified: the
  # teacher has just proved they can read mail there, which is the same proof
  # verification asks for.
  def confirm_email_change!
    return false if pending_email.blank?

    self.email = pending_email
    self.email_verified_at = Time.current
    self.email_verification_token = nil
    clear_email_change_columns
    save
  end

  def clear_email_change!
    update!(pending_email: nil, email_change_token: nil, email_change_sent_at: nil)
  end

  class_methods do
    def new_token
      SecureRandom.urlsafe_base64(TOKEN_BYTES)
    end
  end

  private

  def clear_email_change_columns
    self.pending_email = nil
    self.email_change_token = nil
    self.email_change_sent_at = nil
  end

  # Token sent to user's inbox - proves they own the email address
  def generate_email_verification_token
    self.email_verification_token = self.class.new_token
  end
end
