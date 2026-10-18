require "rails_helper"

RSpec.describe AssessmentChoice, type: :model do
  describe "#label" do
    let(:choice) { described_class.new(key: "known") }

    it "returns the translation for the current locale" do
      expect(I18n.with_locale(:en) { choice.label }).to eq("Know both")
      expect(I18n.with_locale(:ja) { choice.label }).to eq("読みも意味も知っている")
    end
  end

  it "prevents deleting a choice used by saved assessments" do
    choice = described_class.create!(key: "known", position: 4)
    assessment = Analysis.create!(text: "猫").word_assessments.create!(
      word: Word.create!(lemma: "猫", part_of_speech: "名詞"), assessment_choice: choice
    )

    expect(choice.destroy).to be(false)
    expect(choice.errors[:base]).to be_present
    expect(assessment.reload.assessment_choice).to eq(choice)
  end
end
