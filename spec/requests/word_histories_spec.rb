require "rails_helper"

RSpec.describe "Word histories", type: :request do
  before do
    allow(Flashcards::VocabularyLookup).to receive(:call).and_return(Flashcards::VocabularyCollection.new)
  end

  def get_history(**parameters)
    get word_history_path, params: { lemma: "猫", part_of_speech: "名詞", **parameters },
      headers: { "Turbo-Frame" => "word_history" }
  end

  it "shows all saved passages, dates, and assessment totals" do
    word = Word.create!(lemma: "猫", part_of_speech: "名詞")
    known = AssessmentChoice.create!(key: "known", position: 4)
    unknown = AssessmentChoice.create!(key: "unknown", position: 1)
    [ [ "猫。猫。猫。", unknown ], [ "猫がいる", known ], [ "猫を見た", known ] ].each_with_index do |(text, choice), index|
      analysis = Analysis.create!(text: text, created_at: Time.utc(2026, 10, 10 + index, 10))
      analysis.word_assessments.create!(word: word, assessment_choice: choice)
    end
    other = Word.create!(lemma: "猫", part_of_speech: "固有名詞")
    Analysis.create!(text: "別の猫").word_assessments.create!(word: other, assessment_choice: known)

    get_history

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('turbo-frame#word_history [data-history-passage-count]').text).to eq("3")
    expect(document.css("time").first(2).map { |time| time["datetime"] }).to eq([
      Time.utc(2026, 10, 10, 10).iso8601, Time.utc(2026, 10, 12, 10).iso8601
    ])
    expect(document.css("[data-history-entry]").size).to eq(3)
    expect(document.css(".assessment-totals").text.split.join(" ")).to include("Don't know yet: 1", "Know both: 2")
    expect(response.body).to include("猫。猫。猫。", "猫がいる", "猫を見た")
    expect(response.body).not_to include("別の猫")
    expect(response.body).to include("current unsaved analysis is excluded")
  end

  it "shows a new word without creating database records" do
    expect { get_history }.not_to change(Word, :count)

    expect(response.body).to include("This word has no saved history yet", "Not encountered yet")
    expect(Nokogiri::HTML(response.body).at_css('[data-history-passage-count]').text).to eq("0")
  end

  it "renders Japanese dates and labels without missing translations" do
    word = Word.create!(lemma: "猫", part_of_speech: "名詞")
    Analysis.create!(text: "猫").word_assessments.create!(word: word, assessment_choice: AssessmentChoice.create!(key: "known", position: 4))

    get_history(locale: "ja")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("初めて出会った日時", "読みも意味も知っている")
    expect(response.body).not_to include("translation_missing")
  end

  it "shows matching flashcard note information as safe text" do
    note = {
      "noteId" => 123, "modelName" => "Basic", "tags" => [ "animals" ],
      "fields" => { "Meaning" => { "value" => '<b>cat</b><img src=x onerror=alert(1)>' } }
    }
    collection = Flashcards::VocabularyCollection.new([ "猫" ], checked: true, provider: "anki", notes: { "猫" => [ note ] })
    allow(Flashcards::VocabularyLookup).to receive(:call).and_return(collection)

    get_history

    expect(response.body).to include("In flashcards", "Anki", "123", "Basic", "animals", "Meaning", "cat")
    expect(response.body).not_to include("<img", "<b>cat</b>")
  end

  it "keeps history available when the flashcard system cannot be accessed" do
    allow(AnkiConnect::Client).to receive(:new).and_raise(ArgumentError, "Invalid endpoint")
    allow(Flashcards::VocabularyLookup).to receive(:call).and_call_original

    get_history

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Flashcard lookup is unavailable", "no saved history yet")
    expect(response.body).not_to include("Invalid endpoint")
  end

  it "distinguishes unavailable, disabled, and successfully checked but absent" do
    get_history
    expect(response.body).to include("disabled or not configured")
    expect(response.body).not_to include("Flashcard lookup is unavailable")

    allow(Flashcards::VocabularyLookup).to receive(:call).and_return(Flashcards::VocabularyCollection.new([], checked: true))
    get_history
    expect(response.body).to include("Not in flashcards")
    expect(response.body).not_to include("disabled or not configured", "Flashcard lookup is unavailable")
  end
end
