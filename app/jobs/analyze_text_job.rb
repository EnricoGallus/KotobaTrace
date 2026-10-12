class AnalyzeTextJob < ApplicationJob
  queue_as :default

  def perform(text, stream_key, locale = I18n.default_locale.to_s)
    locale = I18n.available_locales.find { |available| available.to_s == locale.to_s } || I18n.default_locale

    I18n.with_locale(locale) do
      tokens = Japanese::Tokenizer.call(text)

      collection = Anki::VocabularyIndex.new

      collection.scan(
        decks: [ "2026 JLPT N2::新完全マスターN2 - 語彙" ],
        expression_field: "Expression"
      )

      analysis = Analysis.new(text: text)
      token_groups = tokens.group_by { |token| [ token.base_form, token.part_of_speech ] }
      existing_words = Word.where(lemma: token_groups.keys.map(&:first).uniq)
        .index_by { |word| [ word.lemma, word.part_of_speech ] }

      token_groups.each do |(lemma, part_of_speech), word_tokens|
        word = existing_words[[ lemma, part_of_speech ]] || Word.new(
          lemma: lemma,
          part_of_speech: part_of_speech,
          dictionary_reading: word_tokens.first.reading
        )
        assessment = analysis.word_assessments.build(word: word)
        assessment.surfaces = word_tokens.map(&:surface).uniq
        assessment.in_anki = vocabulary_token?(word_tokens.first) ?
          collection.include?(lemma) :
          nil
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

  private

  def vocabulary_token?(token)
    %w[名詞 動詞 形容詞].include?(token.part_of_speech)
  end
end
