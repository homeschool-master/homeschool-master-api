# frozen_string_literal: true

class AuthenticationService
  def self.call(email, password)
    new(email, password).call
  end

  def initialize(email, password)
    @email = email
    @password = password
  end

  def call
    @teacher = Teacher.find_by(email: @email)

    error = validate_teacher_exists || validate_password || validate_active
    return error if error

    { success: true, teacher: @teacher }
  end

  private

  def validate_teacher_exists
    return if @teacher

    Rails.logger.warn("Login failed: email not found - #{@email}")
    { success: false, error: 'Invalid email or password' }
  end

  def validate_password
    return if @teacher.authenticate(@password)

    Rails.logger.warn("Login failed: wrong password - #{@teacher.email}")
    { success: false, error: 'Invalid email or password' }
  end

  def validate_active
    return if @teacher.is_active?

    Rails.logger.warn("Login failed: inactive account - #{@teacher.email}")
    { success: false, error: 'Account is deactivated' }
  end
end
