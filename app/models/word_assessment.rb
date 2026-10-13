class WordAssessment < ApplicationRecord
  belongs_to :analysis, inverse_of: :word_assessments
  belongs_to :word, inverse_of: :word_assessments
  belongs_to :assessment_choice, optional: true

  attribute :in_anki, :boolean
  attr_accessor :surfaces, :surface_readings

  accepts_nested_attributes_for :word

  validates :assessment_choice, presence: true, if: -> { assessment_choice_id.present? }
  before_validation :set_assessed_at, if: -> { assessment_choice.present? }

  def word_attributes=(attributes)
    attributes = attributes.to_h.symbolize_keys
    self.word = Word.find_or_initialize_by(
      lemma: attributes[:lemma],
      part_of_speech: attributes[:part_of_speech]
    )
    word.dictionary_reading = attributes[:dictionary_reading] if word.new_record?
  end

  private

  def set_assessed_at
    self.assessed_at ||= Time.current
  end
end
