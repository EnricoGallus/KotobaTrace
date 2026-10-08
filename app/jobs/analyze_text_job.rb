class AnalyzeTextJob < ApplicationJob
  queue_as :default

  def perform(text)
    tokens = Japanese::Tokenizer.call(@text)

    collection = Anki::VocabularyIndex.new

    collection.scan(
      decks: [ "2026 JLPT N2::新完全マスターN2 - 語彙" ],
      expression_field: "Expression"
    )

    @tokens = tokens.map do |token|
      {
        token:,
        in_anki: vocabulary_token?(token) ?
          collection.include?(token.base_form) :
          nil
      }
    end
    AnalyzeController.broadcast_result(@tokens)
  end
end
