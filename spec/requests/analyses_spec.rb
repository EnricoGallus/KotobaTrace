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

    it "re-renders the results with validation errors when saving fails" do
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
                assessment_choice_id: "999999",
                surface_readings: [ "", "ネコ" ],
                surfaces: [ "猫" ]
              }
            }
          }
        },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('<turbo-stream action="update" target="analysis_results">')
      expect(response.body).to include("Assessment choice")
      expect(Nokogiri::HTML(response.body).css("tbody tr td")[2].text.strip).to eq("ネコ")
      expect(Analysis.count).to eq(0)
    end
  end
end
