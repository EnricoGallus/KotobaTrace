class AssessmentChoice < ApplicationRecord
  has_many :word_assessments, dependent: :nullify

  def label
    I18n.t("assessment_choices.#{key}")
  end
end
