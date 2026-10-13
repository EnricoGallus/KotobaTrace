module Japanese
  class VocabularyExtractor
    RULES = [
      VocabularyRules::NameHonorific,
      VocabularyRules::HonorificVerb,
      VocabularyRules::HonorificNoun,
      VocabularyRules::TimeExpression,
      VocabularyRules::NumberCounter,
      VocabularyRules::SuruVerb,
      VocabularyRules::Verb,
      VocabularyRules::ContentWord
    ].freeze

    def self.call(morphemes)
      new(morphemes).call
    end

    def initialize(morphemes, rules: RULES)
      @morphemes = morphemes
      @rules = rules
    end

    def call
      candidates = []
      index = 0
      while index < @morphemes.length
        match = @rules.lazy.map { |rule| rule.call(@morphemes, index) }.find(&:itself)
        if match
          candidates << build_candidate(match)
          index += match.morphemes.length
        else
          index += 1
        end
      end
      candidates
    end

    private

    def build_candidate(match)
      VocabularyCandidate.new(
        surface: match.morphemes.map(&:surface).join,
        base_form: match.base_form,
        reading: combined_reading(match.morphemes),
        part_of_speech: match.part_of_speech,
        kind: match.kind,
        morphemes: match.morphemes
      )
    end

    def combined_reading(morphemes)
      readings = morphemes.map(&:reading)
      readings.all? ? readings.join : nil
    end
  end
end
