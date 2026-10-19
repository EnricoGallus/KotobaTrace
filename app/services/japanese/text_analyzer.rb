module Japanese
  class TextAnalyzer
    MODEL = "gemini-3.8-flash"

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      response = RubyLLM.chat(model: MODEL, provider: :gemini)
        .with_schema(TextAnalysisSchema)
        .ask(prompt)

      build_analysis(response.parsed)
    end

    private

    def prompt
      <<~PROMPT
        Analyze the Japanese text below and return only what is supported by it.

        Extract vocabulary useful to a Japanese learner: content words and meaningful
        expressions, with the exact surface form, dictionary lemma, Japanese part of
        speech, and (when identifiable) the surface reading in katakana. Do not include
        names, numbers, particles, or auxiliary words as vocabulary.

        Extract useful grammar patterns that occur in the text. For each, provide its
        Japanese pattern, a concise meaning, an explanation of its function in this
        context, and an exact source-text excerpt demonstrating it. Write the meaning
        and explanation in #{I18n.locale == :ja ? "Japanese" : "English"}. Do not infer
        patterns or examples that are not present in the source.

        Source text:
        #{@text}
      PROMPT
    end

    def build_analysis(result)
      analysis = Analysis.new(text: @text)
      build_word_assessments(analysis, result.fetch("vocabularies"))
      build_grammar_assessments(analysis, result.fetch("grammar_points"))
      analysis
    end

    def build_word_assessments(analysis, vocabularies)
      groups = vocabularies.group_by { |vocabulary| [ vocabulary.fetch("lemma"), vocabulary.fetch("part_of_speech") ] }
      existing_words = Word.where(lemma: groups.keys.map(&:first).uniq)
        .index_by { |word| [ word.lemma, word.part_of_speech ] }

      groups.each do |(lemma, part_of_speech), occurrences|
        word = existing_words[[ lemma, part_of_speech ]] || Word.new(lemma: lemma, part_of_speech: part_of_speech)
        assessment = analysis.word_assessments.build(word: word)
        assessment.surfaces = occurrences.map { |occurrence| occurrence.fetch("surface") }.uniq
        assessment.surface_readings = occurrences.filter_map { |occurrence| occurrence["reading"] }.uniq
      end
    end

    def build_grammar_assessments(analysis, grammar_points)
      grammar_points.uniq { |grammar_point| grammar_point.fetch("pattern") }.each do |grammar_point|
        analysis.grammar_assessments.build(
          pattern: grammar_point.fetch("pattern"),
          meaning: grammar_point.fetch("meaning"),
          explanation: grammar_point.fetch("explanation"),
          example: grammar_point.fetch("example")
        )
      end
    end
  end
end
