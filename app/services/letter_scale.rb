# frozen_string_literal: true

# The one place the letter scale lives, used both to read a percentage as a
# letter and to turn a letter a teacher typed into a score.
#
# The two directions are exact inverses, which is the property that matters: a
# mark entered as an A has to come back out of the averages as an A. Each
# letter maps to the middle of its own band, five points clear of either edge,
# so no rounding anywhere can push it into the neighbouring letter.
#
# No plus and minus. The app has exactly one scale, and it has no A minus band
# to derive back into: an A minus entered at 91 would read back as a plain A,
# which is the lossy behaviour this class exists to prevent. Adding them means
# adding them to both directions at once.
class LetterScale
  # 90/80/70/60, the ordinary US scale, unchanged from what the progress report
  # has always used.
  THRESHOLDS = [[90, 'A'], [80, 'B'], [70, 'C'], [60, 'D']].freeze
  LOWEST_LETTER = 'F'

  # F is the one band with no midpoint worth using: it runs from 0 to 59, and
  # 30 would punish a teacher who reaches for the letter rather than a number.
  # 50 is the common floor for a failing mark and still sits ten points clear
  # of the D boundary.
  ENTRY_PERCENTAGES = { 'A' => 95, 'B' => 85, 'C' => 75, 'D' => 65, 'F' => 50 }.freeze

  LETTERS = ENTRY_PERCENTAGES.keys.freeze

  def self.letters
    LETTERS
  end

  def self.valid_letter?(letter)
    LETTERS.include?(normalize(letter))
  end

  def self.normalize(letter)
    letter.to_s.strip.upcase
  end

  # What percentage a letter is worth. The key a teacher sees on the page is
  # rendered from this same hash, so the page cannot describe a scale the
  # server is not using.
  def self.percentage_for(letter)
    ENTRY_PERCENTAGES[normalize(letter)]
  end

  # The score a letter becomes on a given assignment. A letter is a share of
  # the work, not a number of points, so an A is 19 on a twenty point quiz and
  # 95 on a hundred point test.
  def self.score_for(letter, points_possible)
    percentage = percentage_for(letter)
    return nil if percentage.nil? || points_possible.nil?

    (points_possible.to_d * percentage / 100).round(2)
  end

  def self.letter_for(percentage)
    return nil if percentage.nil?

    THRESHOLDS.each { |threshold, letter| return letter if percentage >= threshold }
    LOWEST_LETTER
  end
end
