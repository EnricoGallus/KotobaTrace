module Japanese
  module VocabularyRules
    class HonorificVerb
      PREFIXES = %w[お ご].freeze

      def self.call(morphemes, index)
        prefix, verb, helper = morphemes[index, 3]
        return unless prefix&.pos?("接頭詞") && PREFIXES.include?(prefix.surface)
        return unless verb&.pos?("動詞")
        return unless helper&.pos?("動詞") && helper.base_form == "くださる"

        verb_match = Verb.call(morphemes, index + 1)
        VocabularyMatch.new(
          morphemes: [ prefix, *verb_match.morphemes ],
          base_form: verb.base_form, part_of_speech: "動詞", kind: :vocabulary
        )
      end
    end
  end
end
