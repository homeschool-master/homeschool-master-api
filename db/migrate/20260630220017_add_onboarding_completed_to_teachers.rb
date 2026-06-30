# frozen_string_literal: true

class AddOnboardingCompletedToTeachers < ActiveRecord::Migration[7.1]
  def change
    add_column :teachers, :onboarding_completed, :boolean, default: false, null: false
  end
end