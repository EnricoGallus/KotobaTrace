class Word < ApplicationRecord
  has_many :word_assessments, inverse_of: :word, dependent: :destroy
  has_many :analyses, through: :word_assessments
end
