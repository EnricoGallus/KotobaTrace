class AssessmentChoice < ApplicationRecord
  def label
    I18n.t("assessment_choices.#{key}")
  end
end
