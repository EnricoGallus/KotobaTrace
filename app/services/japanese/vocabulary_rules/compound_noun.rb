module Japanese
  module VocabularyRules
    class CompoundNoun
      def self.call(morphemes, index)
        parts = []
        spelling = +""
        match = nil
        cursor = index
        while (morpheme = morphemes[cursor])
          break unless morpheme.pos?("名詞")

          parts << morpheme
          spelling << morpheme.surface
          cursor += 1
          break unless VocabularyLexicon::COMPOUNDS.keys.any? { |word| word.start_with?(spelling) }

          if VocabularyLexicon::COMPOUNDS.key?(spelling)
            match = VocabularyMatch.new(
              morphemes: parts.dup, base_form: spelling.dup,
              part_of_speech: "名詞", kind: :vocabulary
            )
          end
        end
        match
      end
    end
  end
end
