require "rails_helper"
require Rails.root.join("db/migrate/20261019000000_require_word_assessment_choice")

RSpec.describe RequireWordAssessmentChoice, type: :model do
  it "cleans invalid assessments, preserves valid history, and requires future choices" do
    migration = described_class.new
    migration.migrate(:down)
    analysis = Analysis.create!(text: "猫と犬と鳥")
    known = AssessmentChoice.create!(key: "known", position: 4)
    ignore = AssessmentChoice.create!(key: "ignore", position: 0)
    assessments = [ known, ignore, nil ].zip([ "猫", "犬", "鳥" ]).map do |choice, lemma|
      assessment = WordAssessment.new(
        analysis: analysis,
        word: Word.create!(lemma: lemma, part_of_speech: "名詞"),
        assessment_choice: choice
      )
      assessment.save!(validate: false)
      assessment
    end

    migration.migrate(:up)

    expect(WordAssessment.pluck(:id)).to eq([ assessments.first.id ])
    expect(Word.count).to eq(3)
    expect(analysis.reload).to be_persisted
    expect(WordAssessment.connection.columns(:word_assessments).find { |column| column.name == "assessment_choice_id" }.null).to be(false)
  end
end
