# frozen_string_literal: true

class Subject < ApplicationRecord
  # Callbacks
  before_save :nullify_blank_description

  # Associations
  belongs_to :teacher

  # Validations
  #
  # Uniqueness is scoped to the teacher, so two families can both have Math,
  # and case insensitive, because "Math" and "math" are the same confusion the
  # rule exists to prevent. The conditions limit it to subjects still in play:
  # a removed subject keeps its row but releases its name, which is what the
  # matching partial index enforces in the database.
  validates :name,
            presence: true,
            length: { maximum: 100 },
            uniqueness: {
              scope: :teacher_id,
              case_sensitive: false,
              conditions: -> { where(is_active: true) }
            }
  validates :color, length: { maximum: 20 }, allow_blank: true

  # Scopes
  scope :active, -> { where(is_active: true) }

  private

  # Same treatment the student's middle name gets: an empty string from a form
  # is stored as nothing rather than as a blank.
  def nullify_blank_description
    self.description = nil if description.blank?
  end
end
