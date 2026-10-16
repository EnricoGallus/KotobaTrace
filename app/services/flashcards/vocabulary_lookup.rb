module Flashcards
  class VocabularyLookup
    def self.call(
      provider: ENV.fetch("FLASHCARD_PROVIDER", "anki"),
      deck: ENV.fetch("ANKI_DECK", "2026 JLPT N2::新完全マスターN2 - 語彙"),
      expression_field: ENV.fetch("ANKI_EXPRESSION_FIELD", "Expression")
    )
      return VocabularyCollection.new if provider.blank? || provider == "none"

      unless provider == "anki"
        Rails.logger.warn("Unsupported flashcard provider; skipping vocabulary lookup")
        return VocabularyCollection.new
      end

      return VocabularyCollection.new if deck.blank? || expression_field.blank?

      index = Anki::VocabularyIndex.new.scan(decks: [ deck ], expression_field: expression_field)
      VocabularyCollection.new(index.expressions, checked: true)
    rescue StandardError => error
      # Optional enrichment must never prevent analysis or saving.
      Rails.logger.warn("Flashcard vocabulary lookup failed (#{error.class}); continuing without enrichment")
      VocabularyCollection.new
    end
  end
end
