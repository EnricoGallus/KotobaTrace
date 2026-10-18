module Japanese
  module VocabularyRules
    class NounSuffix
      NOUN_SUFFIXES = %w[代 日 費 料].freeze

      def self.call(morphemes, index)
        head = CompoundNoun.call(morphemes, index) || ContentWord.call(morphemes, index)
        return unless head&.part_of_speech == "名詞"

        parts = head.morphemes.dup
        base_form = head.base_form.dup
        part_of_speech = "名詞"
        while (suffix = morphemes[index + parts.length])
          break unless suffix.pos?("名詞") && suffix.subtype?("接尾")

          adjectival = suffix.surface == "的" && suffix.subtype?("形容動詞語幹")
          break unless adjectival || NOUN_SUFFIXES.include?(suffix.surface)

          parts << suffix
          base_form << suffix.surface
          if adjectival
            part_of_speech = "形容動詞"
            break
          end
        end
        return if parts.length == head.morphemes.length

        VocabularyMatch.new(morphemes: parts, base_form: base_form, part_of_speech: part_of_speech, kind: :vocabulary)
      end
    end
  end
end
