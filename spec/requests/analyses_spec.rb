require "rails_helper"

RSpec.describe "Analyses", type: :request do
  describe "GET /analysis/new" do
    it "renders the analysis form and a Turbo Stream subscription" do
      get new_analysis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="stream_key"')
      expect(response.body).to include("turbo-cable-stream-source")
      expect(response.body).to include('id="analysis_results"')
    end

    it "renders the selected locale and a language switcher" do
      get new_analysis_path, params: { locale: "ja" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<html lang="ja">')
      expect(response.body).to include("解析するテキスト")
      expect(response.body).to include("English")
      expect(response.body).to include('action="/analysis?locale=ja"')
    end

    { "de" => "Text zur Analyse", "vi" => "Văn bản cần phân tích" }.each do |locale, label|
      it "renders the #{locale} application with all four language links and no output-language selector" do
        get new_analysis_path, params: { locale: locale }
        expect(response.body).to include("<html lang=\"#{locale}\">", label, "Deutsch", "Tiếng Việt", "日本語", "English")
        expect(response.body).not_to include('name="output_language"', "translation missing")
      end
    end

    it "uses the default locale for unsupported locales" do
      get new_analysis_path, params: { locale: "fr" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<html lang="en">')
      expect(response.body).to include("Text to analyze")
    end
  end

  describe "POST /analysis" do
    it "queues analysis and acknowledges enqueueing without overwriting job results" do
      stream_key = SecureRandom.uuid
      expect(AnalyzeTextJob).to receive(:perform_later).with("猫を見た", stream_key, "en", "attempt-1").and_return(AnalyzeTextJob.new)

      post analysis_path,
        params: { text: "猫を見た", stream_key: stream_key, request_id: "attempt-1" },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
    end

    %w[de vi].each do |language|
      it "uses the #{language} application language for analysis and ignores a separate output language" do
        expect(AnalyzeTextJob).to receive(:perform_later).with(
          "猫", "stream", language, "attempt-1"
        ).and_return(AnalyzeTextJob.new)

        post analysis_path, params: {
          text: "猫", stream_key: "stream", request_id: "attempt-1", locale: language, output_language: "en"
        }

        expect(response).to have_http_status(:accepted)
      end
    end

    it "queues the analysis using the selected locale" do
      stream_key = SecureRandom.uuid
      expect(AnalyzeTextJob).to receive(:perform_later).with("猫を見た", stream_key, "ja", "attempt-1").and_return(AnalyzeTextJob.new)

      post analysis_path,
        params: { text: "猫を見た", stream_key: stream_key, request_id: "attempt-1", locale: "ja" },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
    end
  end

  describe "analysis validation and queue errors" do
    [ nil, "", " \n\t　" ].each do |text|
      it "rejects blank input #{text.inspect} without enqueueing" do
        expect(AnalyzeTextJob).not_to receive(:perform_later)

        post analysis_path, params: { text: text, stream_key: "stream", request_id: "attempt-1" },
          headers: { "Accept" => Mime[:turbo_stream].to_s }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Enter some Japanese text")
        expect(response.body).to include('data-analysis-request-id="attempt-1"')
      end
    end

    it "shows a retryable error if the queue rejects the job" do
      allow(AnalyzeTextJob).to receive(:perform_later).and_return(false)

      post analysis_path, params: { text: "猫", stream_key: "stream", request_id: "attempt-1" },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Retry analysis")
    end

    it "shows a retryable error if enqueueing fails" do
      allow(AnalyzeTextJob).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "Queue offline")

      post analysis_path, params: { text: "猫", stream_key: "stream", request_id: "attempt-1" },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("Retry analysis")
      expect(response.body).not_to include("Queue offline")
    end
  end

  describe "POST /analysis/save" do
    it "creates the analysis, links an existing word, and saves its assessment choice" do
      word = Word.create!(lemma: "猫", part_of_speech: "名詞", dictionary_reading: "ネコ")
      choice = AssessmentChoice.create!(key: "known", position: 4)

      post save_analysis_path,
        params: {
          analysis: {
            text: "猫",
            word_assessments_attributes: {
              "0" => {
                word_attributes: {
                  lemma: "猫",
                  part_of_speech: "名詞",
                  dictionary_reading: "ネコ"
                },
                assessment_choice_id: choice.id,
                in_flashcards: "true",
                surfaces: [ "猫" ]
              }
            }
          }
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      analysis = Analysis.last
      assessment = analysis.word_assessments.sole
      expect(response).to redirect_to(new_analysis_path)
      expect(analysis.text).to eq("猫")
      expect(assessment.word).to eq(word)
      expect(assessment.assessment_choice).to eq(choice)
      expect(assessment.assessed_at).to be_present
    end

    it "creates a word when no matching word exists" do
      choice = AssessmentChoice.create!(key: "unknown", position: 1)

      post save_analysis_path,
        params: {
          analysis: {
            text: "犬",
            word_assessments_attributes: {
              "0" => {
                word_attributes: {
                  lemma: "犬",
                  part_of_speech: "名詞",
                  dictionary_reading: "イヌ"
                },
                assessment_choice_id: choice.id,
                surfaces: [ "犬" ]
              }
            }
          }
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to redirect_to(new_analysis_path)
      expect(Word.find_by!(lemma: "犬", part_of_speech: "名詞").dictionary_reading).to eq("イヌ")
      expect(Analysis.last.words.pluck(:lemma)).to eq([ "犬" ])
    end

    it "saves nested grammar assessments with their assessment choice" do
      choice = GrammarAssessmentChoice.create!(key: "understood", position: 3)

      post save_analysis_path,
        params: {
          analysis: {
            text: "雨が降っている",
            grammar_assessments_attributes: {
              "0" => {
                pattern: "〜ている",
                meaning: "ongoing action",
                explanation: "Describes an action in progress.",
                example: "降っている",
                grammar_assessment_choice_id: choice.id
              }
            }
          }
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      grammar_assessment = Analysis.last.grammar_assessments.sole
      expect(response).to redirect_to(new_analysis_path)
      expect(grammar_assessment).to have_attributes(
        pattern: "〜ている",
        meaning: "ongoing action",
        explanation: "Describes an action in progress.",
        example: "降っている",
        grammar_assessment_choice: choice
      )
      expect(grammar_assessment.assessed_at).to be_present
    end


    def assessment_attributes(lemma, choice_id)
      {
        word_attributes: { lemma: lemma, part_of_speech: "名詞", dictionary_reading: lemma },
        assessment_choice_id: choice_id,
        surfaces: [ lemma ]
      }
    end

    def save_assessments(attributes)
      post save_analysis_path,
        params: { analysis: { text: "猫と犬と鳥", word_assessments_attributes: attributes } },
        headers: { "Accept" => Mime[:turbo_stream].to_s }
    end

    it "skips ignored new and existing words while preserving prior history" do
      ignore = AssessmentChoice.create!(key: "ignore", position: 0)
      known = AssessmentChoice.create!(key: "known", position: 4)
      cat = Word.create!(lemma: "猫", part_of_speech: "名詞")
      history = Analysis.create!(text: "猫").word_assessments.create!(word: cat, assessment_choice: known)

      expect do
        save_assessments({
          "0" => assessment_attributes("猫", ignore.id),
          "1" => assessment_attributes("犬", ignore.id),
          "2" => assessment_attributes("鳥", known.id)
        })
      end.to change(WordAssessment, :count).by(1).and change(Word, :count).by(1)

      expect(response).to redirect_to(new_analysis_path)
      expect(Analysis.last.words.pluck(:lemma)).to eq([ "鳥" ])
      expect(Word.exists?(lemma: "犬")).to be(false)
      expect(history.reload.assessment_choice).to eq(known)
      expect(cat.word_assessments.count).to eq(1)
    end

    it "allows all words to be ignored without saving words or assessments" do
      ignore = AssessmentChoice.create!(key: "ignore", position: 0)

      expect do
        save_assessments({ "0" => assessment_attributes("猫", ignore.id) })
      end.not_to change(WordAssessment, :count)

      expect(response).to redirect_to(new_analysis_path)
      expect(Word.count).to eq(0)
      expect(Analysis.last.word_assessments).to be_empty
    end

    [ nil, "" ].each do |choice_id|
      it "rejects a missing choice #{choice_id.inspect} without saving any part of the analysis" do
        known = AssessmentChoice.create!(key: "known", position: 4)
        ignore = AssessmentChoice.create!(key: "ignore", position: 0)

        save_assessments({
          "0" => assessment_attributes("猫", known.id),
          "1" => assessment_attributes("犬", choice_id),
          "2" => assessment_attributes("鳥", ignore.id)
        })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('role="alert"', "Assessment choice")
        document = Nokogiri::HTML(response.body)
        expect(document.css("tbody select[required]").size).to eq(3)
        expect(document.css("tbody select option[selected]").map { |option| option["value"] }).to include(known.id.to_s, ignore.id.to_s)
        expect(Analysis.count).to eq(0)
        expect(WordAssessment.count).to eq(0)
        expect(Word.count).to eq(0)
      end
    end

    it "re-renders the results with validation errors when saving fails" do
      post save_analysis_path,
        params: {
          analysis: {
            text: "猫", output_language: "de",
            word_assessments_attributes: {
              "0" => {
                word_attributes: {
                  lemma: "猫",
                  part_of_speech: "名詞",
                  dictionary_reading: "ネコ"
                },
                assessment_choice_id: "999999",
                surface_readings: [ "", "ネコ" ],
                surfaces: [ "猫" ], translation: "Katze",
                example_sentence: "猫がいる。", example_translation: "Da ist eine Katze."
              }
            }
          }
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('<turbo-stream action="update" target="analysis_results">')
      expect(response.body).to include("Assessment choice", "Katze", "猫がいる。", "Da ist eine Katze.", 'lang="de"')
      expect(Nokogiri::HTML(response.body).css("tbody tr td")[3].text.strip).to eq("ネコ")
      expect(Analysis.count).to eq(0)
    end
  end
end
