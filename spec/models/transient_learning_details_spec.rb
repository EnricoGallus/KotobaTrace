require "rails_helper"

RSpec.describe "Temporary analysis learning details", type: :model do
  it "saves assessments without persisting translations, generated examples, or output language" do
    vocabulary_choice = AssessmentChoice.create!(key: "known", position: 4)
    grammar_choice = GrammarAssessmentChoice.create!(key: "understood", position: 3)
    analysis = Analysis.new(text: "猫が寝ている。", output_language: "vi")
    vocabulary = analysis.word_assessments.build(
      word: Word.new(lemma: "猫", part_of_speech: "名詞"), assessment_choice: vocabulary_choice,
      translation: "con mèo", example_sentence: "猫がいる。", example_translation: "Có một con mèo."
    )
    grammar = analysis.grammar_assessments.build(
      grammar_assessment_choice: grammar_choice, pattern: "〜ている", meaning: "ongoing action",
      explanation: "Describes an action in progress.", example: "寝ている",
      usage_example: "今、本を読んでいる。", usage_example_translation: "Bây giờ tôi đang đọc sách."
    )
    analysis.save!

    saved_vocabulary = WordAssessment.find(vocabulary.id)
    saved_grammar = GrammarAssessment.find(grammar.id)
    expect(saved_vocabulary.translation).to be_nil
    expect(saved_vocabulary.example_sentence).to be_nil
    expect(saved_vocabulary.example_translation).to be_nil
    expect(saved_grammar.usage_example).to be_nil
    expect(saved_grammar.usage_example_translation).to be_nil
    expect(Analysis.find(analysis.id).output_language).to be_nil
    expect(saved_grammar.example).to eq("寝ている")
    expect(saved_vocabulary.assessment_choice).to eq(vocabulary_choice)
  end
end
