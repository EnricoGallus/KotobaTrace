module Japanese
  module VocabularyRules
    class LexicalExpression
      def self.call(morphemes, index)
        verbal_expression(morphemes, index) || adverbial_expression(morphemes, index)
      end

      def self.verbal_expression(morphemes, index)
        noun, particle, verb = morphemes[index, 3]
        return unless noun&.pos?("名詞") && particle&.pos?("助詞") && particle.subtype?("格助詞")
        return unless verb&.pos?("動詞")

        entry = VocabularyLexicon::VERBAL_EXPRESSIONS.find do |expression|
          expression[:noun] == noun.base_form && expression[:particle] == particle.surface &&
            expression[:verb] == verb.base_form
        end
        return unless entry

        verb_match = Verb.call(morphemes, index + 2)
        return unless verb_match

        VocabularyMatch.new(
          morphemes: [ noun, particle, *verb_match.morphemes ],
          base_form: entry[:base_form], part_of_speech: "表現", kind: :vocabulary
        )
      end

      def self.adverbial_expression(morphemes, index)
        head, particle = morphemes[index, 2]
        # Dictionaries can emit the complete adverb as one token or split に.
        if head&.pos?("副詞") && (base_form = VocabularyLexicon::ADVERBIAL_EXPRESSIONS[head.base_form])
          return VocabularyMatch.new(
            morphemes: [ head ], base_form: base_form,
            part_of_speech: "副詞", kind: :vocabulary
          )
        end
        return unless head && (head.pos?("副詞") || (head.pos?("名詞") && head.subtype?("形容動詞語幹")))
        return unless particle&.pos?("助詞") && particle.surface == "に" && particle.subtype?("副詞化")

        base_form = VocabularyLexicon::ADVERBIAL_EXPRESSIONS["#{head.base_form}に"]
        return unless base_form

        VocabularyMatch.new(
          morphemes: [ head, particle ], base_form: base_form,
          part_of_speech: "副詞", kind: :vocabulary
        )
      end

      private_class_method :verbal_expression, :adverbial_expression
    end
  end
end
