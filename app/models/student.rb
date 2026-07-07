# frozen_string_literal: true

class Student < ApplicationRecord
  # Associations
  belongs_to :teacher

  # Validations
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :grade_level, length: { maximum: 50 }, allow_blank: true
  validates :color, length: { maximum: 20 }, allow_blank: true

  # Scopes
  scope :active, -> { where(is_active: true) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
