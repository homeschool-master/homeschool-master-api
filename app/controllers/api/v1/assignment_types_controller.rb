# frozen_string_literal: true

module Api
  module V1
    # The teacher's own vocabulary for kinds of work, and what each kind counts
    # by default.
    class AssignmentTypesController < BaseController
      before_action :set_type, only: %i[update destroy]

      # GET /api/v1/assignment_types
      # Active only, the same as subjects: a removed type keeps its row so the
      # assignments pointing at it still read, but it is not offered again.
      def index
        types = current_teacher.assignment_types.active.in_display_order
        render_success(types.map { |type| AssignmentTypeSerializer.render(type) })
      end

      # POST /api/v1/assignment_types
      # Always custom: the three built in ones are created with the teacher.
      def create
        type = current_teacher.assignment_types.build(type_params.merge(is_built_in: false))
        return render_validation_errors(type) unless type.save

        render_created(AssignmentTypeSerializer.render(type))
      end

      # PATCH /api/v1/assignment_types/:id
      #
      # A changed default_weight carries an apply mode saying how far back it
      # reaches. Without one the change is new_only, which is the mode that
      # touches no existing work: the safe reading of a request that did not say.
      def update
        return render_invalid_mode unless valid_mode?
        return render_missing_date if mode == 'from_date' && from_date.nil?

        apply_update
      end

      # DELETE /api/v1/assignment_types/:id
      # A soft delete, like a subject: work already typed keeps its type.
      def destroy
        return render_built_in_protected if @type.is_built_in?

        @type.update!(is_active: false)
        render_no_content
      end

      private

      def apply_update
        @type.assign_attributes(type_params.except(:default_weight))
        return render_validation_errors(@type) unless @type.valid?

        result = save_with_weight
        return if performed?

        render_success(AssignmentTypeSerializer.render(@type.reload).merge(updated_count: result))
      end

      # The name and the default travel in one request, so they commit together:
      # a rejected weight must not leave a renamed type behind.
      def save_with_weight
        updated = 0
        @type.transaction do
          @type.save!
          updated = apply_new_default
        end
        updated
      rescue ActiveRecord::RecordInvalid
        render_validation_errors(@type)
        nil
      end

      def apply_new_default
        return 0 if submitted_weight.nil?

        AssignmentTypeDefaultWeight.call(
          type: @type, weight: submitted_weight, mode: mode, from_date: from_date
        ).updated_count
      end

      def set_type
        @type = current_teacher.assignment_types.active.find_by(id: params[:id])
        render_not_found('Assignment type') if @type.nil?
      end

      def type_params
        params.permit(:name, :default_weight)
      end

      def submitted_weight
        params[:default_weight].presence
      end

      def mode
        params[:apply_mode].presence || 'new_only'
      end

      def valid_mode?
        AssignmentTypeDefaultWeight::MODES.include?(mode)
      end

      def from_date
        return nil if params[:from_date].blank?

        Date.parse(params[:from_date].to_s)
      rescue Date::Error
        nil
      end

      def render_invalid_mode
        render_invalid('apply_mode', "must be one of #{AssignmentTypeDefaultWeight::MODES.join(', ')}")
      end

      def render_missing_date
        render_invalid('from_date', 'is required when applying from a date')
      end

      def render_built_in_protected
        render_invalid('base', 'A built in type cannot be removed')
      end

      def render_invalid(field, message)
        render_error('Validation failed', code: 'VALIDATION_ERROR',
                                          status: :unprocessable_entity, details: { field => [message] })
      end
    end
  end
end
