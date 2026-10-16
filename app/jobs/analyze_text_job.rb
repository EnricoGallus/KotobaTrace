class AnalyzeTextJob < ApplicationJob
  queue_as :default

  def perform(text, stream_key, locale = I18n.default_locale.to_s)
    locale = I18n.available_locales.find { |available| available.to_s == locale.to_s } || I18n.default_locale

    I18n.with_locale(locale) do
      morphemes = Japanese::MorphologicalAnalyzer.call(text)
      candidates = Japanese::VocabularyExtractor.call(morphemes)
        .select { |candidate| candidate.kind == :vocabulary }

      collection = Flashcards::VocabularyLookup.call

      analysis = Analysis.new(text: text)
      candidate_groups = candidates.group_by { |candidate| [ candidate.base_form, candidate.part_of_speech ] }
      existing_words = Word.where(lemma: candidate_groups.keys.map(&:first).uniq)
        .index_by { |word| [ word.lemma, word.part_of_speech ] }

      candidate_groups.each do |(lemma, part_of_speech), word_candidates|
        word = existing_words[[ lemma, part_of_speech ]] || Word.new(
          lemma: lemma,
          part_of_speech: part_of_speech,
          dictionary_reading: word_candidates.first.reading
        )
        assessment = analysis.word_assessments.build(word: word)
        assessment.surfaces = word_candidates.map(&:surface).uniq
        assessment.surface_readings = word_candidates.map(&:reading).compact.uniq
        assessment.in_flashcards = collection.include?(lemma) if collection.checked?
      end

      Turbo::StreamsChannel.broadcast_update_to(
        stream_key,
        target: "analysis_results",
        partial: "analyses/results",
        locals: {
          analysis: analysis,
          assessment_choices: AssessmentChoice.order(:position)
        }
      )
    end
  end
end
