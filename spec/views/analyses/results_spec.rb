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
    expect(Nokogiri::HTML(rendered).at_css('input[name$="[dictionary_reading]"]')).to be_nil
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

  it "does not present a saved dictionary reading as an encountered reading when none was supplied" do
    analysis = Analysis.new(text: "記載された")
    analysis.word_assessments.build(
      word: Word.new(lemma: "記載する", part_of_speech: "動詞", dictionary_reading: "キサイスル")
    )

    render partial: "analyses/results", locals: { analysis: analysis, assessment_choices: [] }

    expect(Nokogiri::HTML(rendered).css("tbody tr td")[2].text.strip).to eq("")
  end

  { true => "In flashcards", false => "Not in flashcards", nil => "Not checked" }.each do |membership, label|
    it "displays #{label.inspect} for membership #{membership.inspect}" do
      analysis = Analysis.new(text: "猫")
      analysis.word_assessments.build(
        word: Word.new(lemma: "猫", part_of_speech: "名詞"),
        in_flashcards: membership
      )

      render partial: "analyses/results", locals: { analysis: analysis, assessment_choices: [] }

      document = Nokogiri::HTML(rendered)
      expect(document.css("tbody tr td")[4].at_css("[title]")["title"]).to eq(label)
      expect(document.at_css('input[name="analysis[word_assessments_attributes][0][in_flashcards]"]')).to be_present
    end
  end

  it "explains an empty result without displaying an empty table or Save button" do
    render partial: "analyses/results", locals: {
      analysis: Analysis.new(text: "。"), assessment_choices: [], request_id: "attempt-1"
    }

    expect(rendered).to include("No study vocabulary was found")
    expect(rendered).to include('data-analysis-request-id="attempt-1"')
    expect(Nokogiri::HTML(rendered).css("table, form")).to be_empty
  end

  it "explains unavailable flashcards while keeping vocabulary saveable" do
    analysis = Analysis.new(text: "猫")
    analysis.word_assessments.build(word: Word.new(lemma: "猫", part_of_speech: "名詞"))

    render partial: "analyses/results", locals: {
      analysis: analysis, assessment_choices: [], flashcards_unavailable: true
    }

    expect(rendered).to include("Flashcard lookup is unavailable")
    expect(Nokogiri::HTML(rendered).at_css('input[type="submit"]')["value"]).to eq("Save")
  end
end
