class AnalysesController < ApplicationController
  def new
    @stream_key = SecureRandom.uuid
  end

  def create
    text = params[:text].to_s
    request_id = params.require(:request_id)

    if text.blank?
      render_analysis_error("blank_input", request_id, :unprocessable_content)
      return
    end

    output_language = Japanese::OutputLanguage.normalize(params[:output_language].presence || I18n.locale)
    job = AnalyzeTextJob.perform_later(text, params.require(:stream_key), I18n.locale.to_s, request_id, output_language)
    unless job
      render_analysis_error("failed", request_id, :service_unavailable)
      return
    end

    # The browser shows progress immediately. An empty acknowledgement cannot
    # overwrite results from a job that finishes before this request returns.
    head :accepted
  rescue ActiveJob::EnqueueError => error
    Rails.logger.error("Analysis enqueue failed (#{error.class})")
    render_analysis_error("failed", request_id, :service_unavailable)
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
          assessment_choices: AssessmentChoice.order(:position),
          grammar_assessment_choices: GrammarAssessmentChoice.order(:position)
        }
      ), status: :unprocessable_entity
    end
  end

  private

  def render_analysis_error(message, request_id, status)
    render turbo_stream: turbo_stream.update(
      "analysis_results",
      partial: "analyses/error",
      locals: { message: message, request_id: request_id }
    ), status: status
  end

  def analysis_params
    params.require(:analysis).permit(
      :text, :output_language,
      word_assessments_attributes: [
        :assessment_choice_id,
        :in_flashcards, :translation, :example_sentence, :example_translation,
        { surfaces: [] },
        { surface_readings: [] },
        { word_attributes: %i[lemma part_of_speech dictionary_reading] }
      ],
      grammar_assessments_attributes: %i[
        grammar_assessment_choice_id pattern meaning explanation example usage_example usage_example_translation
      ]
    )
  end
end
