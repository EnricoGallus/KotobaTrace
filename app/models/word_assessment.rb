class WordAssessment < ApplicationRecord
  belongs_to :analysis, inverse_of: :word_assessments
  belongs_to :word, inverse_of: :word_assessments
  belongs_to :assessment_choice, optional: false

  attribute :in_flashcards, :boolean
  attr_accessor :surfaces, :surface_readings

  accepts_nested_attributes_for :word

  validate :assessment_choice_is_not_ignore
  before_validation :set_assessed_at, if: -> { assessment_choice.present? }

  def ignored?
    assessment_choice&.key == "ignore"
  end

  def word_attributes=(attributes)
    attributes = attributes.to_h.symbolize_keys
    self.word = Word.find_or_initialize_by(
      lemma: attributes[:lemma],
      part_of_speech: attributes[:part_of_speech]
    )
    word.dictionary_reading = attributes[:dictionary_reading] if word.new_record?
  end

  private

  def assessment_choice_is_not_ignore
    errors.add(:assessment_choice, :invalid) if ignored?
  end

  def set_assessed_at
    self.assessed_at ||= Time.current
  end
end
