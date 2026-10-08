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

      results = tokens.map do |token|
        {
          token:,
          in_anki: vocabulary_token?(token) ?
            collection.include?(token.base_form) :
            nil
        }
      end

      Turbo::StreamsChannel.broadcast_update_to(
        stream_key,
        target: "analysis_results",
        partial: "analyses/results",
        locals: { results: results }
      )
    end
  end

  private

  def vocabulary_token?(token)
    %w[名詞 動詞 形容詞].include?(token.part_of_speech)
  end
end
