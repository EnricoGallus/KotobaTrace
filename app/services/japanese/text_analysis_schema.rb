module Japanese
  class TextAnalysisSchema < Schematist::Schema
    array :vocabularies, description: "Study-worthy Japanese vocabulary found in the text" do
      object do
        string :surface, description: "The exact written form as it appears in the source text"
        string :lemma, description: "The dictionary form of the vocabulary"
        string :part_of_speech, description: "Japanese part of speech"
        string :reading, required: false, description: "The reading of the surface form in katakana"
      end
    end

    array :grammar_points, description: "Useful Japanese grammar constructs found in the text" do
      object do
        string :pattern, description: "The Japanese grammar pattern"
        string :meaning, description: "A concise meaning in the user's locale"
        string :explanation, description: "How the pattern works in this context, in the user's locale"
        string :example, description: "The exact source text that demonstrates the pattern"
      end
    end
  end
end
