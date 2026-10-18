module Japanese
  module VocabularyRules
    class SuruVerb
      def self.call(morphemes, index)
        noun = CompoundNoun.call(morphemes, index) || ContentWord.call(morphemes, index)
        return unless noun&.part_of_speech == "名詞"

        lexical_entry = VocabularyLexicon::COMPOUNDS[noun.base_form]
        suru_noun = lexical_entry ? lexical_entry[:suru] : noun.morphemes.first.subtype?("サ変接続")
        return unless suru_noun

        verb_index = index + noun.morphemes.length
        verb = morphemes[verb_index]
        return unless verb&.pos?("動詞") && verb.base_form == "する"

        verb_match = Verb.call(morphemes, verb_index)
        return unless verb_match

        VocabularyMatch.new(
          morphemes: [ *noun.morphemes, *verb_match.morphemes ],
          base_form: "#{noun.base_form}する", part_of_speech: "動詞", kind: :vocabulary
        )
      end
    end
  end
end
