module Japanese
  module VocabularyRules
    class SuruVerb
      def self.call(morphemes, index)
        noun, verb = morphemes[index, 2]
        return unless noun&.pos?("名詞") && noun.subtype?("サ変接続")
        return unless verb&.pos?("動詞") && verb.base_form == "する"

        verb_match = Verb.call(morphemes, index + 1)
        VocabularyMatch.new(
          morphemes: [ noun, *verb_match.morphemes ],
          base_form: "#{noun.base_form}する", part_of_speech: "動詞", kind: :vocabulary
        )
      end
    end
  end
end
