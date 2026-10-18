class AssessmentChoice < ApplicationRecord
  has_many :word_assessments, dependent: :restrict_with_error

  def label
    I18n.t("assessment_choices.#{key}")
  end
end
