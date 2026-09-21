# frozen_string_literal: true

# When the figures on this card were frozen, and null while they are still
# being computed from current grades.
#
# This is what decides how a card renders, rather than issued_at, and the two
# are not the same question. Issuing always captures, so an issued card always
# has both. But a new version of an issued card inherits its predecessor's
# frozen figures while still being an editable draft: captured, not issued.
# One rule covers every case: a card shows what it has captured and computes
# only what it has not.
class AddCapturedAtToReportCards < ActiveRecord::Migration[7.1]
  def change
    add_column :report_cards, :captured_at, :datetime
  end
end
