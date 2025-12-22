# frozen_string_literal: true

class RefreshToken < ApplicationRecord
  belongs_to :teacher

  validates :token, presence: true, uniqueness: true
  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def valid_token?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def self.find_valid_by_token(token)
    active.find_by(token: token)
  end

  def self.revoke_all_for_teacher(teacher_id)
    where(teacher_id: teacher_id).update_all(revoked_at: Time.current)
  end
end
