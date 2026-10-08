class AnalysesController < ApplicationController
  def new
    @stream_key = SecureRandom.uuid
  end

  def create
    text = params[:text].to_s
    AnalyzeTextJob.perform_later(text, params.require(:stream_key))

    render turbo_stream: turbo_stream.update(
      "analysis_results",
      "Analysis in progress…"
    )
  end
end
