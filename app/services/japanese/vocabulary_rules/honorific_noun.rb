module Japanese
  module VocabularyRules
    class HonorificNoun
      PREFIXES = %w[お ご].freeze

      def self.call(morphemes, index)
        prefix = morphemes[index]
        return unless prefix&.pos?("接頭詞") && PREFIXES.include?(prefix.surface)
        noun = NounSuffix.call(morphemes, index + 1) ||
          CompoundNoun.call(morphemes, index + 1) || ContentWord.call(morphemes, index + 1)
        return unless noun && %w[名詞 形容動詞].include?(noun.part_of_speech)

        VocabularyMatch.new(
          morphemes: [ prefix, *noun.morphemes ], base_form: noun.base_form,
          part_of_speech: noun.part_of_speech, kind: :vocabulary
        )
      end
    end
  end
end
