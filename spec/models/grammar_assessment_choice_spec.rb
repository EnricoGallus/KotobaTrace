require "rails_helper"

RSpec.describe GrammarAssessmentChoice, type: :model do
  it "returns the translation for the current locale" do
    choice = described_class.new(key: "partly_understood")

    expect(I18n.with_locale(:en) { choice.label }).to eq("Partly understand")
    expect(I18n.with_locale(:ja) { choice.label }).to eq("少しわかる")
  end

  it "prevents deleting a choice used by a saved grammar assessment" do
    choice = described_class.create!(key: "understood", position: 3)
    assessment = Analysis.create!(text: "雨が降っている").grammar_assessments.create!(
      pattern: "〜ている",
      meaning: "ongoing action",
      explanation: "Describes an action in progress.",
      example: "降っている",
      grammar_assessment_choice: choice
    )

    expect(choice.destroy).to be(false)
    expect(choice.errors[:base]).to be_present
    expect(assessment.reload.grammar_assessment_choice).to eq(choice)
  end
end
