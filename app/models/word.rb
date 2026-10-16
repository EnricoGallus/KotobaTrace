class Word < ApplicationRecord
  has_many :word_assessments, inverse_of: :word, dependent: :destroy
  has_many :analyses, through: :word_assessments

  def self.saved_passage_counts(word_ids)
    WordAssessment.where(word_id: word_ids.compact).group(:word_id).count
  end
end
