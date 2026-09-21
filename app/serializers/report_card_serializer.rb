# frozen_string_literal: true

class ReportCardSerializer
  def self.render(card, detail: true)
    new(card, detail: detail).to_h
  end

  def initialize(card, detail: true)
    @card = card
    @detail = detail
  end

  # The list view needs the heading of each card and not the work behind every
  # subject of it, which on a full term is hundreds of rows per card.
  def to_h
    base.merge(@detail ? view : {})
  end

  private

  def base # rubocop:disable Metrics/MethodLength
    {
      id: @card.id,
      teacher_id: @card.teacher_id,
      student_id: @card.student_id,
      group_id: @card.group_id,
      version: @card.version,
      title: @card.title,
      period_start: @card.period_start,
      period_end: @card.period_end,
      comments: @card.comments,
      issued: @card.issued?,
      issued_at: @card.issued_at,
      captured: @card.captured?,
      captured_at: @card.captured_at,
      latest_version: @card.latest_version?,
      created_at: @card.created_at
    }
  end

  def view
    ReportCardView.call(@card)
  end
end
