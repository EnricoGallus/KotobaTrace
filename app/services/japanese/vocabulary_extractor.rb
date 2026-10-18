module Japanese
  class VocabularyExtractor
    RULES = [
      VocabularyRules::NameHonorific,
      VocabularyRules::HonorificVerb,
      VocabularyRules::HonorificNoun,
      VocabularyRules::TimeExpression,
      VocabularyRules::NumberCounter,
      VocabularyRules::SuruVerb,
      VocabularyRules::NounSuffix,
      VocabularyRules::CompoundNoun,
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
      # Every rule sees only uninterrupted source text. This also protects
      # existing honorific, counter and helper rules from crossing list entries.
      @morphemes.slice_when { |left, right| left.end_offset != right.start_offset }
        .flat_map { |run| extract_run(run) }
    end

    private

    def extract_run(morphemes)
      candidates = []
      index = 0
      while index < morphemes.length
        match = @rules.lazy.map { |rule| rule.call(morphemes, index) }.find(&:itself)
        if match
          candidate = build_candidate(match)
          candidates << VocabularyDisambiguator.call(
            candidate, following: morphemes[index + match.morphemes.length]
          )
          index += match.morphemes.length
        else
          index += 1
        end
      end
      candidates
    end

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
