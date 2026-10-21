module Japanese
  class VocabularyDisambiguator
    def self.call(candidate, following: nil)
      return candidate unless candidate.part_of_speech == "動詞"

      head = candidate.morphemes.first
      noun = VocabularyLexicon::NOMINAL_STEMS[candidate.surface]
      if noun && head.conjugation_form == "連用形" && nominal_context?(following)
        candidate.with(base_form: noun, part_of_speech: "名詞")
      elsif (base = VocabularyLexicon::POTENTIAL_FORMS[candidate.base_form])
        candidate.with(base_form: base)
      else
        candidate
      end
    end

    def self.nominal_context?(following)
      following.nil? || following.pos?("記号") ||
        (following.pos?("助詞") && %w[が を に の].include?(following.surface))
    end

    private_class_method :nominal_context?
  end
end
