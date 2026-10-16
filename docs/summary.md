# KotobaTrace — Project Instructions

## Product vision

KotobaTrace is a Japanese-learning companion focused on the Japanese a learner actually encounters.

The core idea is not to become another generic dictionary or flashcard application. KotobaTrace should help learners answer:

- Which words do I actually encounter in real Japanese?
- Which of those words do I know, not know, or want to ignore?
- Which words repeatedly cause me trouble?
- In which contexts have I encountered a word before?
- Does my real-world recognition match what I supposedly know from flashcards?
- Which vocabulary and grammar should I focus on next?

The long-term principle is:

> Learn the Japanese you actually encounter.

## Core workflow

A user pastes either:

1. Japanese text, such as an article, JLPT reading passage, book excerpt, or lesson material.
2. A list of Japanese vocabulary.

KotobaTrace analyzes the input and produces learner-facing vocabulary candidates.

For every candidate, the application should eventually be able to show information such as:

- surface form as encountered in the source text
- normalized/base form
- reading
- part of speech
- meaning/translation when available
- how many times the learner has encountered it
- how often they marked it known or unknown
- previous example contexts
- optional Anki information
- later, related grammar information

The learner can classify vocabulary, initially with states such as:

- Known
- Unknown
- Ignore

More nuanced states may be introduced later, for example:

- Can read but do not know the meaning
- Know meaning but cannot read
- Unsure

Selections are persisted so KotobaTrace gradually builds a personal vocabulary history.

Repeated failure matters more than simply being absent from a flashcard deck.

For example:

    促す
    encountered: 5
    marked unknown: 4
    marked known: 1

is a much stronger study candidate than a word encountered once.

## Japanese analysis architecture

Do not treat MeCab output as learner-facing vocabulary.

The architecture must preserve separate responsibilities:

    Japanese text
        ↓
    Japanese::MorphologicalAnalyzer
        ↓
    raw morphemes
        ├───────────────→ Japanese::VocabularyExtractor
        │                     ↓
        │                learner-facing vocabulary candidates
        │
        └───────────────→ Japanese::GrammarExtractor
                              ↓
                         grammar / expressions / keigo

A future contextual layer may also exist:

    VocabularyExtractor
        ↓
    Japanese::VocabularyDisambiguator
        ↓
    context-sensitive corrections

### Japanese::MorphologicalAnalyzer

This layer wraps MeCab/Natto.

Its responsibility is:

> Faithfully report what the morphological analyzer says.

It must not try to decide what a learner should study.

It should preserve useful morphological metadata including:

- surface
- base form
- reading
- part of speech
- POS subtypes
- conjugation type
- conjugation form
- position/index

Do not add learner-oriented merging or filtering here.

Known analyzer ambiguities are acceptable. Examples already observed include:

    雨が降りそう
    MeCab may resolve 降り as 降りる instead of 降る

and:

    何時までに
    MeCab may give the reading イツ where context requires ナンジ

Do not solve these with hard-coded special cases in MorphologicalAnalyzer.

### Japanese::VocabularyExtractor

This layer consumes raw morphemes and creates vocabulary candidates that make sense to a learner.

It may combine multiple morphemes into one learner-facing occurrence.

Examples:

    お + 申し込み
    → surface: お申し込み
    → base_form: 申し込み

    記載さ + れ + た
    → surface: 記載された
    → base_form: 記載する

    持っ + て + いく
    → surface: 持っていく
    → base_form: 持つ

    三 + 十 + 分
    → surface: 三十分
    → kind: number/time expression

    田中 + 様
    → surface: 田中様
    → kind: name
    → normally hidden from vocabulary study

Rules should be small, ordered, and independently testable.

Specific rules must run before generic fallback rules.

Example rule categories include:

- name + honorific
- honorific noun
- honorific verb
- number/counter expressions
- time expressions
- verbs and auxiliary constructions
- ordinary content words

Avoid turning VocabularyExtractor into a giant collection of ad-hoc Japanese grammar conditions.

When a new problem is found in real study material, add or improve the smallest appropriate rule.

### Japanese::GrammarExtractor

This will be built later.

It must consume the raw morphemes directly rather than consuming VocabularyExtractor output.

This is important because vocabulary extraction intentionally removes or groups particles, auxiliaries, prefixes, and grammatical material that GrammarExtractor will need.

Examples of future grammar/expression candidates:

    お〜ください
    〜までに
    〜により
    〜たとおり
    〜ていく
    〜必要がある
    ございます

Vocabulary and grammar are separate learning concepts and should remain separate in the data model.

## Occurrences versus vocabulary

Do not discard duplicate occurrences too early.

If a word appears three times in one text, KotobaTrace should preserve all three occurrences internally.

For example:

    受付 occurrence 1
    受付 occurrence 2
    受付 occurrence 3

The UI may aggregate them into:

    受付
    occurrences in this text: 3

but the original positions and contexts should remain available.

This is important for future encounter history and contextual examples.

## Machine suggestions are not absolute truth

Japanese NLP will never be perfect.

KotobaTrace should follow this principle:

> The machine proposes; the learner can correct.

Learner-facing base forms and classifications should eventually be editable when analysis is wrong.

Do not silently pretend automatic analysis is infallible.

## Anki integration

Anki is an optional enrichment source, not a hard dependency.

Current local integration uses AnkiConnect.

A vocabulary index can scan configured decks and fields and answer whether a normalized expression already exists.

Example:

    効く
    → found in configured Anki vocabulary deck

    促す
    → not found

Anki also potentially provides useful study information later:

- deck
- note/card IDs
- review count
- lapses
- Again/Hard/Good/Easy history
- interval
- modification time

This enables useful comparisons such as:

    mature Anki card
    +
    repeatedly marked unknown in real Japanese
    =
    card knowledge is not transferring well to real reading

However, AnkiConnect is local to Anki Desktop. A Rails server hosted on AWS cannot directly access a user's localhost.

Do not architect the application so that Anki is required for normal operation.

Possible future integration mechanisms include:

- browser-to-local AnkiConnect bridge
- KotobaTrace Anki add-on
- local companion/sync application
- persisted Anki snapshot
- export/import fallback

For now, keep Anki access behind a small abstraction so the transport can change later.

## Dictionary integration

Dictionary data is enrichment, not the core product.

Do not make the entire application depend on one dictionary provider.

Potential sources include JMdict or hosted dictionary APIs.

JMdict is large, requires parsing/importing, updating, attribution, and license compliance. Do not build a large dictionary ingestion system unless the product actually needs it.

The application should preferably expose dictionary access through a small boundary such as:

    Dictionary::Lookup.call(word)

so the underlying provider can be replaced.

Keep the domain model language-neutral where practical. Avoid fields such as:

    english_definition

Prefer structures that could eventually support:

    language: "en"
    language: "vi"
    language: "de"

Vietnamese may become an important future learner language, but it is not part of the current MVP.

## Personal learning history

The most important persistent data belongs to KotobaTrace itself, not Anki or the dictionary.

Examples:

- encountered vocabulary
- occurrence contexts
- encounter count
- known count
- unknown count
- ignore status
- first seen
- last seen
- learner corrections
- later grammar history

A future Study Inbox should prioritize recurring difficulty.

Example:

    促す       unknown 4 / 5 encounters
    著しい     unknown 3 / 3
    伴う       unknown 2 / 6

This personalized history is one of the main differentiators of the product.

## Future AI features

AI should enhance the learner's existing history rather than replace deterministic analysis.

Potential uses include:

- contextual disambiguation
- explanations of vocabulary in context
- grammar explanations
- generated example sentences
- personalized reading exercises
- multiple-choice questions
- exercises built around words or grammar the learner repeatedly fails

Example future workflow:

    Generate N2 reading exercise
    using:
      促す
      伴う
      著しい
      〜ざるを得ない

AI-generated content should be treated as generated material and not as authoritative dictionary data.

## Rails architecture

Current technology direction:

- Rails 8.1
- Ruby 4
- PostgreSQL
- Hotwire
- Turbo Frames
- Turbo Streams
- Stimulus
- RSpec
- Solid Queue where background processing is useful
- esbuild
- Tailwind CSS
- Kamal for deployment later

Prefer conventional Rails architecture.

The project is also intentionally being used to gain practical experience with:

- Stimulus
- Turbo Frames
- Turbo Streams
- background jobs
- server-rendered interactive UI

Use those technologies where they naturally solve the problem rather than artificially forcing them into the codebase.

A natural analysis flow is:

    user submits text
        ↓
    Rails creates analysis
        ↓
    background job performs Japanese analysis
        ↓
    Turbo Stream updates analysis results
        ↓
    Stimulus handles immediate client-side interaction

Stimulus should generally handle browser behavior such as:

- button states
- keyboard shortcuts
- highlighting
- selection controls
- filtering/hiding results

Turbo should generally handle server-backed UI updates and form submission.

Avoid replacing Turbo with manual fetch requests unless there is a concrete reason.

## Development principles

- Prefer the smallest conventional Rails solution.
- Do not overengineer.
- Do not create abstractions before a real use case requires them.
- Keep classes focused on one responsibility.
- Prefer composition and simple rule objects over large inheritance hierarchies.
- Keep external integrations behind small boundaries.
- Do not introduce new dependencies without explaining why they are necessary.
- Use RSpec for tests.
- Add targeted tests when behavior changes.
- Diagnose the cause of a problem before rewriting code.
- Preserve raw source information when later features may need it.
- Do not silently normalize or discard information unless the product requirement clearly demands it.
- Explain unfamiliar architectural decisions so the developer can understand and maintain the code.
- Avoid large AI-generated rewrites.
- Build incrementally from real Japanese examples rather than attempting to model the entire Japanese language upfront.

## Current product direction

The immediate goal is a usable vocabulary-analysis workflow:

    paste Japanese text or vocabulary list
        ↓
    morphological analysis
        ↓
    learner-oriented vocabulary extraction
        ↓
    filter obvious noise
        ↓
    show candidates
        ↓
    display prior encounter information
        ↓
    optionally enrich with Anki/dictionary information
        ↓
    learner marks Known / Unknown / Ignore
        ↓
    save encounter history

Once this works well with real N2 study material, expand into:

    Study Inbox
        ↓
    grammar extraction/tracking
        ↓
    dictionary enrichment
        ↓
    optional Anki synchronization
        ↓
    personalized AI-generated practice