class Analysis < ApplicationRecord
  has_many :word_assessments, inverse_of: :analysis, dependent: :destroy
  has_many :words, through: :word_assessments

  accepts_nested_attributes_for :word_assessments
end
