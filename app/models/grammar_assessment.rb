class GrammarAssessment < ApplicationRecord
  belongs_to :analysis, inverse_of: :grammar_assessments
  belongs_to :grammar_assessment_choice, optional: false

  attr_accessor :usage_example, :usage_example_translation

  validates :pattern, :meaning, :explanation, :example, presence: true
  validate :assessment_choice_is_not_ignore
  before_validation :set_assessed_at, if: -> { grammar_assessment_choice.present? }

  def ignored?
    grammar_assessment_choice&.key == "ignore"
  end

  private

  def assessment_choice_is_not_ignore
    errors.add(:grammar_assessment_choice, :invalid) if ignored?
  end

  def set_assessed_at
    self.assessed_at ||= Time.current
  end
end
