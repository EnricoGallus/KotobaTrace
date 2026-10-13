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
end
