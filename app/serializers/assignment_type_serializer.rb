# frozen_string_literal: true

class AssignmentTypeSerializer
  def self.render(type)
    new(type).to_h
  end

  def initialize(type)
    @type = type
  end

  # is_built_in rides along because the client has to know which rows offer a
  # rename and a remove and which only offer a default weight.
  def to_h
    {
      id: @type.id,
      teacher_id: @type.teacher_id,
      name: @type.name,
      default_weight: @type.default_weight,
      is_built_in: @type.is_built_in,
      created_at: @type.created_at
    }
  end
end
