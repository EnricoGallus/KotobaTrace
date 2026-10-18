module Japanese
  # Deliberately small, reviewed lexical evidence. Unknown noun sequences stay
  # separate; expand this list with real examples rather than joining all nouns.
  module VocabularyLexicon
    COMPOUNDS = {
      "専業主婦" => { suru: false },
      "意見交換" => { suru: true }
    }.freeze

    NOMINAL_STEMS = { "流行り" => "流行り" }.freeze
    POTENTIAL_FORMS = { "乗れる" => "乗る" }.freeze
  end
end
