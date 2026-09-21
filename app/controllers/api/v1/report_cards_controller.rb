# frozen_string_literal: true

module Api
  module V1
    # Saved copies of a student's grades for a period.
    #
    # A card is created as a draft, edited freely, then issued once. Issuing
    # freezes it. Editing an issued card is not an edit: it creates the next
    # version and leaves the one that was handed over alone.
    class ReportCardsController < BaseController
      before_action :set_card, only: %i[show update destroy issue refresh versions]

      # GET /api/v1/report_cards?student_id=
      #
      # One row per card rather than one per version: the highest version in
      # each group is the one that stands, and the rest are reached from it.
      def index
        cards = current_teacher.report_cards.includes(:student)
        cards = cards.where(student_id: params[:student_id]) if params[:student_id].present?

        render_success(latest_of_each(cards).map { |card| ReportCardSerializer.render(card, detail: false) })
      end

      # GET /api/v1/report_cards/:id
      def show
        render_success(ReportCardSerializer.render(@card))
      end

      # GET /api/v1/report_cards/:id/versions
      # Every version of this card, oldest first, so any one can be opened.
      def versions
        render_success(@card.versions.map { |version| ReportCardSerializer.render(version, detail: false) })
      end

      # POST /api/v1/report_cards
      def create
        card = current_teacher.report_cards.build(card_params)
        card.group_id = SecureRandom.uuid
        card.version = 1
        return render_validation_errors(card) unless card.save

        apply_entries(card)
        render_created(ReportCardSerializer.render(card.reload))
      end

      # PATCH /api/v1/report_cards/:id
      #
      # On a draft this edits in place. On an issued card it creates the next
      # version and edits that, so the response is the new version and the old
      # one is untouched.
      def update
        target = @card.issued? ? ReportCardVersion.call(@card) : @card
        target.assign_attributes(card_params)
        return render_validation_errors(target) unless target.save

        apply_entries(target)
        render_success(ReportCardSerializer.render(target.reload))
      end

      # POST /api/v1/report_cards/:id/issue
      # Freezes the card. Everything it will ever need to render is copied onto
      # it, so a later rescore cannot reach it.
      def issue
        return render_already_issued if @card.issued?

        ReportCardSnapshot.call(@card)
        render_success(ReportCardSerializer.render(@card.reload))
      end

      # POST /api/v1/report_cards/:id/refresh
      # Puts a version's inherited figures back to current grades. Explicit,
      # so figures never move on their own.
      def refresh
        return render_already_issued if @card.issued?

        ReportCardRefresh.call(@card)
        render_success(ReportCardSerializer.render(@card.reload))
      end

      # DELETE /api/v1/report_cards/:id
      #
      # A draft can go: nothing was handed to anyone. An issued card cannot,
      # because the record of what was issued is the entire point of it.
      def destroy
        return render_issued_is_permanent if @card.issued?

        @card.destroy
        render_no_content
      end

      private

      def latest_of_each(cards)
        cards.to_a.group_by(&:group_id).values.map { |group| group.max_by(&:version) }
             .sort_by { |card| [card.period_start, card.created_at] }.reverse
      end

      def set_card
        @card = current_teacher.report_cards.find_by(id: params[:id])
        render_not_found('Report card') if @card.nil?
      end

      def card_params
        params.permit(:student_id, :title, :period_start, :period_end, :comments,
                      :overall_override_letter, :overall_override_reason)
      end

      # The per subject comments and overrides a teacher writes. Stored the
      # moment she writes them, on a draft whose figures are still live: her
      # words are hers, only the arithmetic is recomputed.
      def apply_entries(card)
        submitted_entries.each do |submitted|
          entry = card.report_card_entries.find_or_initialize_by(subject_id: submitted[:subject_id])
          entry.subject_name = submitted[:subject_name].presence || entry.subject_name ||
                               subject_name_for(card, submitted[:subject_id])
          entry.assign_attributes(submitted.slice(:override_letter, :override_reason, :comments))
          entry.save!
        end
      end

      def submitted_entries
        return [] unless params[:entries].is_a?(Array)

        params.permit(entries: %i[subject_id subject_name override_letter override_reason comments])[:entries]
              .map(&:to_h).map(&:symbolize_keys)
      end

      def subject_name_for(card, subject_id)
        card.teacher.subjects.find_by(id: subject_id)&.name.to_s
      end

      def render_already_issued
        render_conflict('This report card has already been issued.')
      end

      def render_issued_is_permanent
        render_conflict('An issued report card cannot be deleted. It is the record of what was handed over.')
      end

      def render_conflict(message)
        render_error(message, code: 'VALIDATION_ERROR', status: :unprocessable_entity)
      end
    end
  end
end
