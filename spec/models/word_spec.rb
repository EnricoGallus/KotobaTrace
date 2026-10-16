require "rails_helper"

RSpec.describe Word, type: :model do
  it "counts saved passages once, including passages with repeated words and no assessment" do
    word = described_class.create!(lemma: "猫", part_of_speech: "名詞")
    unknown = AssessmentChoice.create!(key: "unknown", position: 1)
    first = Analysis.create!(text: "猫。猫。猫。")
    second = Analysis.create!(text: "猫がいる。")
    first.word_assessments.create!(word: word, assessment_choice: unknown)
    second.word_assessments.create!(word: word)

    expect(described_class.saved_passage_counts([ word.id, nil ])).to eq(word.id => 2)
    expect(word.reload.analyses.count).to eq(2)
    expect(word.word_assessments.where(assessment_choice: unknown).count).to eq(1)
    expect(word.analyses.pluck(:text)).to contain_exactly("猫。猫。猫。", "猫がいる。")
    expect(described_class.saved_passage_counts([])).to be_empty
  end
end
