# frozen_string_literal: true

class Subject < ApplicationRecord
  # Callbacks
  before_save :nullify_blank_description

  # Associations
  belongs_to :teacher

  # The API never destroys a subject, it flips is_active, so an assignment keeps
  # pointing at a removed subject and its history survives. This cascade exists
  # for the one case that does destroy rows: deleting the teacher. Restricting
  # instead would be a guard that never helps in normal use and breaks that
  # cascade, since the teacher's subjects are destroyed before their
  # assignments are.
  has_many :assignments, dependent: :destroy

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
