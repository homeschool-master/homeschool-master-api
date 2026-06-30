# frozen_string_literal: true

class TeacherSerializer
  def self.render(teacher)
    new(teacher).to_h
  end

  def initialize(teacher)
    @teacher = teacher
  end

  def to_h # rubocop:disable Metrics/MethodLength
    {
      id: @teacher.id,
      first_name: @teacher.first_name,
      last_name: @teacher.last_name,
      email: @teacher.email,
      notify_account_updates: @teacher.notify_account_updates,
      notify_product_updates: @teacher.notify_product_updates,
      notify_homeschool_resources: @teacher.notify_homeschool_resources,
      onboarding_completed: @teacher.onboarding_completed,
      created_at: @teacher.created_at
    }
  end
end
