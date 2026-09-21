# frozen_string_literal: true

# Who owns an assignment's weight: the teacher, or the type it belongs to.
#
# The question is about the request rather than the number. A weight she typed
# is hers whatever it says, including when it matches the default exactly.
# Deciding it by comparing against the default instead meant a teacher who
# deliberately typed 1 when the default was 1 got an inherited weight, and the
# next change to that default moved work she had already settled.
#
# Three cases, told apart by what the request carries:
#
#   no weight key      leave it alone. On a new assignment that means the
#                      type's default, inherited.
#   weight: null       hand it back to the type and follow the default again.
#   weight: <number>   she typed it. Hers, whatever the number.
#
# There is deliberately no upper bound here. A weight of 30 is a real thing to
# want and the form warns about it rather than the server refusing it. A
# negative one is refused, by the model.
module AssignmentWeighting
  extend ActiveSupport::Concern

  private

  def apply_weight(assignment)
    return assignment.inherit_weight! if inherit_weight_requested?
    return assignment.override_weight!(params[:weight]) if params[:weight].present?

    # Nothing submitted: a new assignment still needs a number to start from.
    assignment.inherit_weight! if assignment.new_record?
  end

  def inherit_weight_requested?
    params.key?(:weight) && params[:weight].nil?
  end
end
