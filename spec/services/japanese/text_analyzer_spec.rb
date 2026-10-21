require "rails_helper"

RSpec.describe Japanese::TextAnalyzer do
  it "requests structured vocabulary and grammar and builds grouped assessments" do
    existing_word = Word.create!(lemma: "食べる", part_of_speech: "動詞", dictionary_reading: "タベル")
    response = Struct.new(:parsed).new(
      {
        "vocabularies" => [
          { "surface" => "食べて", "lemma" => "食べる", "part_of_speech" => "動詞", "reading" => "タベテ",
            "translation" => "essen", "example_sentence" => "毎朝パンを食べる。",
            "example_translation" => "Ich esse jeden Morgen Brot." },
          { "surface" => "食べ", "lemma" => "食べる", "part_of_speech" => "動詞", "reading" => "タベ" }
        ],
        "grammar_points" => [
          {
            "pattern" => "〜ている", "meaning" => "ongoing action",
            "explanation" => "Describes an action in progress.", "example" => "食べている",
            "usage_example" => "今、本を読んでいる。", "usage_example_translation" => "Ich lese gerade ein Buch."
          }
        ]
      }
    )
    chat = double("chat")
    allow(RubyLLM).to receive(:chat).with(model: described_class::MODEL, provider: :gemini).and_return(chat)
    allow(chat).to receive(:with_schema).with(Japanese::TextAnalysisSchema).and_return(chat)
    expect(chat).to receive(:ask).with(/食べている/).and_return(response)

    analysis = described_class.call("食べている", output_language: "de")

    expect(analysis).to be_a(Analysis)
    expect(analysis).not_to be_persisted
    expect(analysis.word_assessments.size).to eq(1)
    expect(analysis.word_assessments.first).to have_attributes(
      translation: "essen", example_sentence: "毎朝パンを食べる。",
      example_translation: "Ich esse jeden Morgen Brot.",
      word: existing_word, surfaces: [ "食べて", "食べ" ], surface_readings: [ "タベテ", "タベ" ]
    )
    expect(analysis.grammar_assessments.sole).to have_attributes(
      pattern: "〜ている", meaning: "ongoing action",
      explanation: "Describes an action in progress.", example: "食べている",
      usage_example: "今、本を読んでいる。", usage_example_translation: "Ich lese gerade ein Buch."
    )
    expect(existing_word.reload.dictionary_reading).to eq("タベル")
  end

  { "en" => "English", "ja" => "Japanese", "de" => "German", "vi" => "Vietnamese" }.each do |code, name|
    it "uses the requested #{name} output language independently of the interface locale" do
      chat = double("chat")
      allow(RubyLLM).to receive(:chat).and_return(chat)
      allow(chat).to receive(:with_schema).and_return(chat)
      expect(chat).to receive(:ask) do |prompt|
        expect(prompt).to include("Output language for translations, meanings, and explanations: #{name}.")
        Struct.new(:parsed).new({ "vocabularies" => [], "grammar_points" => [] })
      end

      analysis = I18n.with_locale(:en) { described_class.call("。", output_language: code) }
      expect(analysis.output_language).to eq(code)
    end
  end

  it "builds an empty analysis when the response contains no vocabulary or grammar" do
    chat = double("chat", with_schema: nil)
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).with(Japanese::TextAnalysisSchema).and_return(chat)
    allow(chat).to receive(:ask).and_return(Struct.new(:parsed).new({ "vocabularies" => [], "grammar_points" => [] }))

    analysis = described_class.call("。")

    expect(analysis.text).to eq("。")
    expect(analysis.word_assessments).to be_empty
    expect(analysis.grammar_assessments).to be_empty
  end
end
