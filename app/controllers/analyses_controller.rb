class AnalysesController < ApplicationController
  def new
    @stream_key = SecureRandom.uuid
  end

  def create
    text = params[:text].to_s
    AnalyzeTextJob.perform_later(text, params.require(:stream_key), I18n.locale.to_s)

    render turbo_stream: turbo_stream.update(
      "analysis_results",
      t("analyses.in_progress")
    )
  end
end
