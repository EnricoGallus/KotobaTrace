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
    attributes = analysis_params
    @analysis = Analysis.new(text: attributes[:text])

    Analysis.transaction do
      attributes.fetch(:word_assessments_attributes, {}).each_value do |assessment_attributes|
        word = Word.find_or_initialize_by(
          lemma: assessment_attributes[:lemma],
          part_of_speech: assessment_attributes[:part_of_speech]
        )
        word.dictionary_reading = assessment_attributes[:dictionary_reading] if word.new_record?

        assessment = @analysis.word_assessments.build(word: word)
        if assessment_attributes[:assessment_choice_id].present?
          assessment.assessment_choice = AssessmentChoice.find_by(id: assessment_attributes[:assessment_choice_id])
          raise ActionController::BadRequest, "Invalid assessment choice" unless assessment.assessment_choice
          assessment.assessed_at = Time.current
        end
        assessment.in_anki = boolean_from_form(assessment_attributes[:in_anki])
        assessment.surfaces = assessment_attributes[:surfaces] || []
      end

      @analysis.save!
    end

    render turbo_stream: turbo_stream.update(
      "analysis_results",
      partial: "analyses/results",
      locals: {
        analysis: @analysis,
        assessment_choices: AssessmentChoice.order(:position),
        saved: true
      }
    )
  end

  private

  def analysis_params
    params.require(:analysis).permit(
      :text,
      word_assessments_attributes: [
        :lemma,
        :part_of_speech,
        :dictionary_reading,
        :assessment_choice_id,
        :in_anki,
        { surfaces: [] }
      ]
    )
  end

  def boolean_from_form(value)
    case value
    when "true" then true
    when "false" then false
    end
  end
end
