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
  end

  describe "POST /analysis" do
    it "queues analysis and responds with an in-progress Turbo Stream" do
      stream_key = SecureRandom.uuid
      expect(AnalyzeTextJob).to receive(:perform_later).with("猫を見た", stream_key)

      post analysis_path,
        params: { text: "猫を見た", stream_key: stream_key },
        headers: { "Accept" => Mime[:turbo_stream].to_s }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('<turbo-stream action="update" target="analysis_results">')
      expect(response.body).to include("Analysis in progress…")
    end
  end
end
