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
    it "queues analysis and responds with an in-progress Turbo Stream" do
      stream_key = SecureRandom.uuid
      expect(AnalyzeTextJob).to receive(:perform_later).with("猫を見た", stream_key, "en")

      post analysis_path,
        params: { text: "猫を見た", stream_key: stream_key },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('<turbo-stream action="update" target="analysis_results">')
      expect(response.body).to include("Analysis in progress…")
    end

    it "queues the analysis using the selected locale" do
      stream_key = SecureRandom.uuid
      expect(AnalyzeTextJob).to receive(:perform_later).with("猫を見た", stream_key, "ja")

      post analysis_path,
        params: { text: "猫を見た", stream_key: stream_key, locale: "ja" },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("解析中…")
    end
  end
end
