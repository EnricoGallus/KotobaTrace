class GrammarAssessmentChoice < ApplicationRecord
  has_many :grammar_assessments, dependent: :restrict_with_error

  def label
    I18n.t("grammar_assessment_choices.#{key}")
  end
end
