# frozen_string_literal: true

# A kind of work, and how much that kind counts by default.
#
# Three are created for every teacher and marked built in: Assignment, Quiz and
# Test. A teacher can add her own, so a family that grades Narrations or Lab
# Reports can name them, and the list behaves like subjects: unique per teacher,
# case insensitive, removed by flipping is_active rather than by deleting, so
# assignments keep pointing at a type that is no longer offered.
class AssignmentType < ApplicationRecord
  BUILT_IN_NAMES = %w[Assignment Quiz Test].freeze
  # The default every type starts at. Grades behave exactly as they did before
  # types existed until a teacher chooses otherwise.
  STARTING_WEIGHT = 1

  # Associations
  belongs_to :teacher
  # Nullifying is not an option, since an assignment must have a type. Removal
  # goes through is_active, and this cascade only ever runs when the teacher
  # themselves is deleted.
  has_many :assignments, dependent: :destroy

  # Validations
  validates :name,
            presence: true,
            length: { maximum: 100 },
            uniqueness: {
              scope: :teacher_id,
              case_sensitive: false,
              conditions: -> { where(is_active: true) }
            }
  # Zero is allowed, the same as an assignment's own weight: a type for practice
  # work that is recorded but does not count is a real thing to want.
  validates :default_weight, numericality: { greater_than_or_equal_to: 0 }
  validate :built_in_name_is_unchanged
  validate :built_in_stays_active

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :built_in, -> { where(is_built_in: true) }
  scope :custom, -> { where(is_built_in: false) }
  # Built in first and in their own order, then the teacher's own alphabetically:
  # the three everyone shares stay where they were put rather than being
  # scattered through the custom names.
  scope :in_display_order, lambda {
    order(Arel.sql("is_built_in DESC, array_position(ARRAY['Assignment','Quiz','Test']::varchar[], name), lower(name)"))
  }

  # Every teacher starts with the same three. Called when a teacher is created,
  # so a new account can set work on its first day.
  def self.create_built_ins_for(teacher)
    BUILT_IN_NAMES.map do |name|
      teacher.assignment_types.create!(name: name, default_weight: STARTING_WEIGHT, is_built_in: true)
    end
  end

  private

  # The three built in names are the shared vocabulary: a teacher who wants
  # "Exam" adds one rather than renaming Test underneath every assignment that
  # already points at it.
  def built_in_name_is_unchanged
    return unless is_built_in? && name_changed? && persisted?

    errors.add(:name, 'cannot be changed on a built in type')
  end

  def built_in_stays_active
    return unless is_built_in? && is_active_changed? && !is_active?

    errors.add(:is_active, 'cannot be removed on a built in type')
  end
end
