class WordAssessment < ApplicationRecord
  belongs_to :analysis, inverse_of: :word_assessments
  belongs_to :word, inverse_of: :word_assessments
  belongs_to :assessment_choice, optional: true

  attr_accessor :in_anki, :surfaces
end
