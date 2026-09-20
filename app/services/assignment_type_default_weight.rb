# frozen_string_literal: true

# Changing what a kind of work counts by default, and deciding how far back
# that change reaches.
#
# Three modes, because all three are things a teacher means at different times:
#
#   new_only  the default changes and nothing already set moves. What she wants
#             when the old work was graded under the old policy on purpose.
#   all       every assignment of that type that never had a weight of its own
#             takes the new number, past work included.
#   from_date the real case this exists for: she is in September and realises
#             she meant tests to count 3 from August 1. Tests due before that
#             keep what they had.
#
# What no mode touches is an assignment whose weight the teacher set by hand.
# If she made one test count 5, changing the test default to 3 leaves that test
# at 5, because an explicit choice about one piece of work outranks a default
# changed afterwards. That is what weight_overridden records, and it is why
# these modes can be a filter on rows rather than a rewrite of history.
class AssignmentTypeDefaultWeight
  MODES = %w[new_only all from_date].freeze

  Result = Struct.new(:updated_count, keyword_init: true)

  def self.call(type:, weight:, mode:, from_date: nil)
    new(type: type, weight: weight, mode: mode, from_date: from_date).call
  end

  def initialize(type:, weight:, mode:, from_date: nil)
    @type = type
    @weight = weight
    @mode = mode
    @from_date = from_date
  end

  def call
    updated = 0

    @type.transaction do
      @type.update!(default_weight: @weight)
      updated = apply_to_existing
    end

    Result.new(updated_count: updated)
  end

  private

  # update_all rather than a loop: the rows are being set to one number that
  # does not depend on any of them, and going through the model would fire the
  # callback that decides inherited from overridden, which would immediately
  # mark every row it just touched as overridden.
  def apply_to_existing
    return 0 if @mode == 'new_only'

    scope = @type.assignments.inheriting_weight
    scope = scope.due_on_or_after(@from_date) if @mode == 'from_date'
    scope.update_all(weight: @weight, updated_at: Time.current)
  end
end
