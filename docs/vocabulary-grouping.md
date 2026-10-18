# Vocabulary grouping

The tokenizer supplies evidence; extraction rules decide what is useful to assess
as one word. Grouping is deliberately conservative: missing a compound is easier
to review than merging unrelated words and recording the wrong assessment.

## Source boundaries

`Morpheme` retains the original token index, POS and conjugation tags, unknown-word
status, and character start/end offsets. Raw tokens are never rewritten.
The extractor partitions tokens wherever offsets reveal intervening whitespace.
Spaces, tabs, line breaks and punctuation prevent rules from joining across them.
Japanese full-width spaces may themselves be raw symbol tokens; rules stop at those
too. Every candidate retains its complete source morphemes and exact encountered
surface. Repeated occurrences remain separate until the result screen groups them.

## Evidence for a group

1. Grammatical patterns: existing honorifics, number/counters, relative time,
   suru constructions and verb helpers retain their ordered rules. Contracted
   `てる` / `でる` must be tagged as non-independent verbs following a verb.
   `て + ます` is also retained as part of the verb occurrence. A non-independent
   or suffix verb cannot start a standalone vocabulary candidate.
2. Approved noun suffixes: a noun can absorb `代`, `日`, `費`, or `料` when the
   tokenizer marks the following token as a noun suffix. Adjectival `的` also
   requires the `形容動詞語幹` subtype and produces a `形容動詞` candidate.
   Numeric counters and relative time keep priority over these rules.
   Unmatched noun suffix fragments are excluded by the generic fallback.
3. Reviewed lexical compounds: `VocabularyLexicon::COMPOUNDS` initially contains
   `専業主婦` and `意見交換`. The compound matcher takes the longest exact
   supported spelling consisting of adjacent noun tokens. Entries explicitly
   record whether they can form a suru verb. Thus `意見交換された` has lemma
   `意見交換する`, while `専業主婦` does not acquire a suru interpretation.
   Honorific noun and suffix rules can wrap compound heads.

Adjacent nouns alone are insufficient evidence: `採用家庭` stays as two words.
Particles are also boundaries: `気持ちの面` yields `気持ち` and `面`.
No external dictionary service is required by these rules.

## Contextual interpretation

`VocabularyDisambiguator` runs on candidates and leaves raw morphemes intact.
Its deliberately small lexical mappings cover:

- `流行り`: a verb-stem token is treated as a noun only in a permitted nominal
  context (selected following particles or the end of an occurrence).
- `乗れる`: the known potential lemma maps to `乗る`, preserving the encountered
  surface and its reading, including inflected `乗れた`.

These are lexical entries, not general suffix-stripping heuristics. Other ambiguous
stems and potential forms remain as analyzed until supported by evidence and tests.
A typo such as `引き継く` is not silently changed to `引き継ぐ`.

## Readings and dictionary consistency

A candidate's reading belongs to its complete encountered surface. If any source
reading is unavailable, extraction does not fabricate a partial reading. It does
not derive a dictionary reading from an inflected surface. New analyses leave
`Word#dictionary_reading` unset and preserve any pre-existing value. The result
screen displays only current encountered readings, including after validation
errors; existing historical values are not rewritten by this change.

MeCab feature fields use CSV quoting. NAIST's optional trailing metadata also
contains unescaped XML quotes, so parsing uses Ruby CSV's liberal mode. Both real
quoted punctuation and ordinary Japanese tokens have regression coverage.

Development containers, CI and production install NAIST-jdic and explicitly select
its directory with `MECAB_DICDIR`. Outside those environments, set that variable to
your installed compatible dictionary directory. The system default is used when
it is unset; a different dictionary can produce different classifications.

## Extending coverage

Add an exact compound entry only after reviewing its spelling, meaning and suru
behavior. Do not add a general join-all-nouns fallback. For each new pattern, test:

- Complete surface, normalized form, reading and POS from real MeCab output.
- An adjacent unrelated word that must remain separate.
- Space, newline and punctuation boundaries.
- Composition with applicable honorifics, suffixes or suru endings.
- Repeated occurrences and preservation of original source metadata.

A larger dictionary can eventually replace the small compound lexicon behind the
same lookup boundary. It still needs source boundaries and the negative tests.
Tokenizer reconstruction tests alone do not establish correct vocabulary grouping.
