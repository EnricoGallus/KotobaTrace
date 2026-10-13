require "rails_helper"

RSpec.describe "analyses/_results", type: :view do
  it "displays current full surface readings instead of a saved head reading" do
    analysis = Analysis.new(text: "記載された")
    word = Word.new(lemma: "記載する", part_of_speech: "動詞", dictionary_reading: "キサイサ")
    assessment = analysis.word_assessments.build(word: word)
    assessment.surfaces = [ "記載された" ]
    assessment.surface_readings = [ "キサイサレタ" ]

    render partial: "analyses/results", locals: { analysis: analysis, assessment_choices: [] }

    cells = Nokogiri::HTML(rendered).css("tbody tr td")
    expect(cells[2].text.strip).to eq("キサイサレタ")
    expect(word.dictionary_reading).to eq("キサイサ")
  end

  it "does not fall back to a partial saved reading when the source reading is unknown" do
    analysis = Analysis.new(text: "記載された")
    word = Word.new(lemma: "記載する", part_of_speech: "動詞", dictionary_reading: "キサイサ")
    assessment = analysis.word_assessments.build(word: word)
    assessment.surfaces = [ "記載された" ]
    assessment.surface_readings = []

    render partial: "analyses/results", locals: { analysis: analysis, assessment_choices: [] }

    expect(Nokogiri::HTML(rendered).css("tbody tr td")[2].text.strip).to eq("")
  end
end
