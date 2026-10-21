class AnalyzeTextJob < ApplicationJob
  queue_as :default

  def perform(text, stream_key, locale = I18n.default_locale.to_s, request_id = nil)
    locale = I18n.available_locales.find { |available| available.to_s == locale.to_s } || I18n.default_locale

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stage = "analyzing"
    I18n.with_locale(locale) do
      Rails.logger.info("Analysis request_id=#{request_id} stage=#{stage}")
      analysis = Japanese::TextAnalyzer.call(text, output_language: Japanese::OutputLanguage.normalize(locale))
      stage = "flashcards"
      Rails.logger.info("Analysis request_id=#{request_id} stage=#{stage}")
      collection = Flashcards::VocabularyLookup.call
      if collection.checked?
        analysis.word_assessments.each do |assessment|
          assessment.in_flashcards = collection.include?(assessment.word.lemma)
        end
      end

      stage = "broadcasting"
      Rails.logger.info("Analysis request_id=#{request_id} stage=#{stage}")
      Turbo::StreamsChannel.broadcast_update_to(
        stream_key,
        target: "analysis_results",
        partial: "analyses/results",
        locals: {
          analysis: analysis,
          assessment_choices: AssessmentChoice.order(:position),
          grammar_assessment_choices: GrammarAssessmentChoice.order(:position),
          request_id: request_id,
          flashcards_unavailable: collection.unavailable?
        }
      )
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
      Rails.logger.info("Analysis request_id=#{request_id} stage=completed elapsed=#{elapsed}s")
    rescue StandardError => error
      Rails.logger.error("Analysis failed request_id=#{request_id} stage=#{stage}\n#{error.full_message}")
      Turbo::StreamsChannel.broadcast_update_to(
        stream_key,
        target: "analysis_results",
        partial: "analyses/error",
        locals: { message: "failed", request_id: request_id }
      )
    end
  end
end
