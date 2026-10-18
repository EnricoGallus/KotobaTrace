require 'rails_helper'

RSpec.describe WordAssessment, type: :model do
  it "casts the transient Anki value as a boolean" do
    assessment = described_class.new(in_flashcards: "false")

    expect(assessment.in_flashcards).to be(false)
  end

  it "requires an assessment choice" do
    assessment = described_class.new(
      analysis: Analysis.new(text: "猫"),
      word: Word.new(lemma: "猫", part_of_speech: "名詞")
    )

    expect(assessment).not_to be_valid
    expect(assessment.errors[:assessment_choice]).to be_present
  end

  it "rejects Ignore when saving an assessment directly" do
    assessment = described_class.new(
      analysis: Analysis.new(text: "猫"),
      word: Word.new(lemma: "猫", part_of_speech: "名詞"),
      assessment_choice: AssessmentChoice.create!(key: "ignore", position: 0)
    )

    expect(assessment.save).to be(false)
    expect(assessment.errors[:assessment_choice]).to be_present
    expect(Word.count).to eq(0)
  end

  it "enforces a choice in the database even when validation is bypassed" do
    assessment = described_class.new(
      analysis: Analysis.create!(text: "猫"),
      word: Word.create!(lemma: "猫", part_of_speech: "名詞")
    )

    expect { assessment.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
  end
end
