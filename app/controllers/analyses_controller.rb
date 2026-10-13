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

  def save
    @analysis = Analysis.new(analysis_params)

    if @analysis.save
      redirect_to new_analysis_path
    else
      render turbo_stream: turbo_stream.update(
        "analysis_results",
        partial: "analyses/results",
        locals: {
          analysis: @analysis,
          assessment_choices: AssessmentChoice.order(:position)
        }
      ), status: :unprocessable_entity
    end
  end

  private

  def analysis_params
    params.require(:analysis).permit(
      :text,
      word_assessments_attributes: [
        :assessment_choice_id,
        :in_anki,
        { surfaces: [] },
        { word_attributes: %i[lemma part_of_speech dictionary_reading] }
      ]
    )
  end
end
