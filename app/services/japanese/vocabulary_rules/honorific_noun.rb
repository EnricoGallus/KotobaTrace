module Japanese
  module VocabularyRules
    class HonorificNoun
      PREFIXES = %w[お ご].freeze

      def self.call(morphemes, index)
        prefix, noun = morphemes[index, 2]
        return unless prefix&.pos?("接頭詞") && PREFIXES.include?(prefix.surface)
        return unless noun&.pos?("名詞")
        return unless ContentWord.call(morphemes, index + 1)

        VocabularyMatch.new(
          morphemes: [ prefix, noun ], base_form: noun.base_form,
          part_of_speech: "名詞", kind: :vocabulary
        )
      end
    end
  end
end
