# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LetterScale do
  describe 'entry values' do
    it 'maps each letter to a percentage' do
      expect(described_class::ENTRY_PERCENTAGES).to eq('A' => 95, 'B' => 85, 'C' => 75, 'D' => 65, 'F' => 50)
    end

    it 'offers no plus or minus letters, since the scale has no band to derive them back into' do
      expect(described_class.letters).to eq(%w[A B C D F])
    end
  end

  # The property the whole feature rests on: a mark entered as an A has to come
  # back out of the arithmetic as an A. Checked for every letter rather than
  # for a sample, because one that does not round trip is a silently wrong grade.
  describe 'round tripping' do
    described_class.letters.each do |letter|
      it "derives #{letter} back to itself" do
        percentage = described_class.percentage_for(letter)
        expect(described_class.letter_for(percentage)).to eq(letter)
      end
    end

    # A letter is a share of the work, so it has to survive being turned into
    # points on assignments that are not out of one hundred.
    [1, 3, 20, 50, 250].each do |possible|
      it "derives every letter back to itself on a #{possible} point assignment" do
        described_class.letters.each do |letter|
          score = described_class.score_for(letter, possible)
          percentage = score / possible * 100

          expect(described_class.letter_for(percentage)).to eq(letter)
        end
      end
    end

    it 'sits every letter clear of both edges of its band' do
      described_class.letters.each do |letter|
        percentage = described_class.percentage_for(letter)
        boundaries = described_class::THRESHOLDS.map(&:first)

        expect(boundaries.map { |edge| (percentage - edge).abs }.min).to be >= 5
      end
    end
  end

  describe '.score_for' do
    it 'takes the letter as a share of what the work is out of' do
      expect(described_class.score_for('A', 20)).to eq(19)
      expect(described_class.score_for('C', 50)).to eq(37.5)
    end

    it 'accepts a lowercase letter' do
      expect(described_class.score_for('a', 100)).to eq(95)
    end

    it 'returns nothing for a letter that is not on the scale' do
      expect(described_class.score_for('A+', 100)).to be_nil
    end
  end

  describe '.letter_for' do
    it 'uses the 90/80/70/60 scale the progress report has always used' do
      expect(described_class.letter_for(90)).to eq('A')
      expect(described_class.letter_for(89.99)).to eq('B')
      expect(described_class.letter_for(60)).to eq('D')
      expect(described_class.letter_for(59.99)).to eq('F')
    end

    it 'has no letter for no percentage' do
      expect(described_class.letter_for(nil)).to be_nil
    end
  end
end
