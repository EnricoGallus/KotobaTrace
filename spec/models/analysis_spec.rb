require 'rails_helper'

RSpec.describe Analysis, type: :model do
  it "accepts nested word assessments and nested words" do
    analysis = described_class.new(
      text: "猫",
      word_assessments_attributes: {
        "0" => {
          word_attributes: {
            lemma: "猫",
            part_of_speech: "名詞",
            dictionary_reading: "ネコ"
          },
          surfaces: [ "猫" ]
        }
      }
    )

    assessment = analysis.word_assessments.first

    expect(assessment.word).to have_attributes(
      lemma: "猫",
      part_of_speech: "名詞",
      dictionary_reading: "ネコ"
    )
    expect(assessment.surfaces).to eq([ "猫" ])
  end

  it "rejects blank text when saving directly" do
    analysis = described_class.new(text: "　 ")

    expect(analysis).not_to be_valid
    expect(analysis.errors[:text]).to be_present
  end

  it "accepts nested grammar assessments" do
    analysis = described_class.new(
      text: "雨が降っている",
      grammar_assessments_attributes: {
        "0" => {
          pattern: "〜ている",
          meaning: "ongoing action",
          explanation: "Describes an action in progress.",
          example: "降っている"
        }
      }
    )

    expect(analysis.grammar_assessments.sole).to have_attributes(
      pattern: "〜ている",
      meaning: "ongoing action",
      explanation: "Describes an action in progress.",
      example: "降っている"
    )
  end

  it "skips ignored new grammar assessments when saving" do
    ignore = GrammarAssessmentChoice.create!(key: "ignore", position: 0)
    analysis = described_class.new(
      text: "雨が降っている",
      grammar_assessments_attributes: {
        "0" => {
          pattern: "〜ている",
          meaning: "ongoing action",
          explanation: "Describes an action in progress.",
          example: "降っている",
          grammar_assessment_choice: ignore
        }
      }
    )

    expect { analysis.save! }.not_to change(GrammarAssessment, :count)
  end
end
