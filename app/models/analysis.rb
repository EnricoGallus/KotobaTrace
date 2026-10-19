class Analysis < ApplicationRecord
  has_many :word_assessments, inverse_of: :analysis, dependent: :destroy
  has_many :grammar_assessments, inverse_of: :analysis, dependent: :destroy
  has_many :words, through: :word_assessments

  validates :text, presence: true

  accepts_nested_attributes_for :word_assessments
  accepts_nested_attributes_for :grammar_assessments

  before_validation :skip_ignored_assessments

  private

  def skip_ignored_assessments
    word_assessments.each do |assessment|
      assessment.mark_for_destruction if assessment.new_record? && assessment.ignored?
    end
    grammar_assessments.each do |assessment|
      assessment.mark_for_destruction if assessment.new_record? && assessment.ignored?
    end
  end
end
