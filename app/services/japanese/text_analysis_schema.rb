module Japanese
  class TextAnalysisSchema < Schematist::Schema
    array :vocabularies, description: "All lexical vocabulary in every source item, including common and inflected words; include words also used in grammar examples" do
      object do
        string :surface, description: "The exact written form as it appears in the source text"
        string :lemma, description: "The lexical dictionary form, undoing inflection (e.g. 移れた → 移る, 強制される → 強制する)"
        string :part_of_speech, description: "Japanese part of speech"
        string :translation, description: "Concise vocabulary meaning in context in the selected output language"
        string :example_sentence, description: "A newly written, short Japanese sentence using this vocabulary in the same sense"
        string :example_translation, description: "Translation of example_sentence into the selected output language"
        string :reading, required: false, description: "The reading of the surface form in katakana"
      end
    end

    array :grammar_points, description: "Useful Japanese grammar constructs found in the text" do
      object do
        string :pattern, description: "The Japanese grammar pattern"
        string :meaning, description: "A concise meaning in the selected output language"
        string :explanation, description: "How the pattern works in this context, in the selected output language"
        string :example, description: "The exact source text that demonstrates the pattern, not a generated sentence"
        string :usage_example, description: "A newly written, short Japanese sentence demonstrating this grammar pattern"
        string :usage_example_translation, description: "Translation of usage_example into the selected output language"
      end
    end
  end
end
