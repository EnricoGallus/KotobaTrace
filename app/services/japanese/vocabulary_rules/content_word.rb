module Japanese
  module VocabularyRules
    class ContentWord
      ALLOWED_POS = %w[名詞 形容詞 副詞].freeze
      EXCLUDED_SUBTYPES = %w[数 固有名詞 非自立].freeze

      def self.call(morphemes, index)
        morpheme = morphemes[index]
        return unless morpheme && ALLOWED_POS.include?(morpheme.part_of_speech)
        return if EXCLUDED_SUBTYPES.any? { |type| morpheme.subtype?(type) }

        VocabularyMatch.new(
          morphemes: [ morpheme ], base_form: morpheme.base_form,
          part_of_speech: morpheme.part_of_speech, kind: :vocabulary
        )
      end
    end
  end
end
