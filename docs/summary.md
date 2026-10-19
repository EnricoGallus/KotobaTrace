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

KotobaTrace uses AI to extract vocabulary and grammar from the submitted source.
The implemented review flow has separate tabs and one shared **Save all** action.

Vocabulary displays encountered form, base form and contextual translation,
encountered reading, and learner assessment. Flashcard status and prior encounters
sit inside the base-form cell. Part of speech remains part of word identity but
is not shown in its own column. Usage examples are expandable in both tabs;
grammar's original source excerpt stays distinct from its generated example.

The application supports English, Japanese, German, and Vietnamese. The language
menu controls both interface text and AI translations/explanations. Japanese
forms and example sentences remain Japanese. `Japanese::TextAnalyzer` accepts an
explicit `output_language:` parameter; it does not select a language with a
Japanese/English conditional inside the prompt.

Vocabulary choices are Ignore, Don't know yet, Reading only, Meaning only, and
Know both. Grammar choices are Ignore, Don't know this pattern yet, Partly
understand, and Understand. Every item must have a choice before saving either
tab. Invalid submission shows remaining counts and a message without changing the
user's tab. Bulk vocabulary assessment fills only unselected choices.

Successful analysis collapses the input without clearing it. The source can be
reopened for editing. The compact app bar contains the product name and language
menu; a shared sticky footer saves both result types together. Word history opens
in place without losing the current review.

Selections and original source text are persisted on explicit save. An Ignore
choice skips creating that item's new assessment; it does not erase existing
history or permanently suppress future suggestions. An all-ignored submission
can still save the source analysis.

Repeated failure matters more than simply being absent from a flashcard deck.

For example:

    促す
    encountered: 5
    marked unknown: 4
    marked known: 1

is a much stronger study candidate than a word encountered once.

## Japanese analysis architecture

The current user-facing analysis is handled by `Japanese::TextAnalyzer`, which
uses RubyLLM with a Schematist response schema to produce vocabulary and grammar
assessments from the passage. Keep these as separate learning concepts.

    Japanese text
        ↓
    Japanese::TextAnalyzer
        ↓
    RubyLLM structured response
        ├──→ grouped vocabulary → WordAssessment
        └──→ grammar pattern, example, meaning, explanation → GrammarAssessment

The local `Japanese::MorphologicalAnalyzer` and `Japanese::VocabularyExtractor`
remain separately testable services; they are not currently called by the
user-facing analysis flow.

The separate local pipeline also has a candidate-level contextual layer:

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

### Japanese::TextAnalyzer

This is the current user-facing analyzer. It requests schema-constrained
vocabulary and grammar results through RubyLLM and returns an unsaved `Analysis`
containing word assessments grouped by lemma and part of speech, plus distinct
grammar assessments. Grammar assessments preserve the pattern, source example,
meaning, and contextual explanation independently from vocabulary records.

The schema and prompt require source-grounded vocabulary surfaces and grammar
source excerpts. Teaching examples are explicitly newly generated sentences and
must be presented separately from source quotations. The prompt requests full
lexical coverage, normalization of inflected forms, and vocabulary extraction
independently of grammar extraction, including reported omission examples.

Vocabulary translations, generated sentences and their translations, encountered
forms/readings, flashcard membership, and output language are temporary review
attributes. Grammar's additional generated usage example and translation are also
temporary. They survive a validation-error rerender via form fields, but are not
persisted. Existing grammar fields (pattern, source excerpt, meaning, explanation)
are saved with the learner's choice. Preserve this boundary unless a product
requirement explicitly changes it.

Readings, translations, explanations, and generated examples can be wrong. They
are not authoritative dictionary data. Mocked structured-response specs verify
application behavior, not live model accuracy or latency. Maintain a separate
real-material evaluation before declaring extraction quality solved.

The deterministic local pipeline remains useful for focused extraction tests
and can be reintroduced behind this service boundary if needed. Do not assume it
is the source for the current analysis workflow.

Examples of grammar/expression candidates:

    お〜ください
    〜までに
    〜により
    〜たとおり
    〜ていく
    〜必要がある
    ございます

Vocabulary and grammar are separate learning concepts and should remain separate in the data model.

## Passage encounters versus repetitions

Keep raw morphemes and vocabulary candidates separate through extraction, then
show one grouped row per normalized word and part of speech.

Personal history counts one encounter per word per saved passage. If a word
appears three times in one passage, save one word/analysis link and one learner
assessment, not three encounters or independent recognition failures. Do not
persist within-passage repetition counts or individual occurrence records for
this workflow.

Use saved analysis/word links to calculate passage counts, first/last encounters,
and assessment totals. Retain the original passage for later review. Unsaved
analyses do not contribute to history. A word-history dialog keeps the learner's
current analysis and selections in place.

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

English, Japanese, German, and Vietnamese are already supported for the interface
and AI output. Dictionary-backed senses in those languages remain a separate,
future enrichment feature.

## Personal learning history

The most important persistent data belongs to KotobaTrace itself, not Anki or the dictionary.

Examples:

- encountered vocabulary
- original saved passages
- saved passage encounter count
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

The current analysis uses AI for passage-grounded vocabulary and grammar
extraction. Further AI features should enhance the learner's existing history
without replacing saved learner assessments or presenting generated material as
authoritative dictionary data.

Contextual vocabulary translations, grammar explanations, and generated usage
examples are already part of the current review. Further uses include:

- contextual disambiguation and correction assistance
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

The implemented analysis flow is:

    user submits source text in the selected application locale
        ↓
    request enqueues AnalyzeTextJob and responds 202 Accepted
        ↓
    Japanese::TextAnalyzer calls RubyLLM for structured vocabulary and grammar
        ↓
    optional flashcard lookup enriches the unsaved analysis
        ↓
    a Turbo Stream broadcasts the results to the page's subscription
        ↓
    learner reviews both tabs; Stimulus handles local review behavior
        ↓
    Save all posts the assessments; Rails validates and saves together

Connection readiness and enqueue acknowledgment are different from job
completion. The browser waits for its subscription, retains progress after
acknowledgment, and matches terminal streams by request ID. It accepts a late
completion of the current request after timeout and rejects superseded requests.
The timeout unlocks the form; it does not cancel server work.

Jobs log analyzing, flashcard lookup, broadcasting, and completion stages. A
completed broadcast still does not prove browser receipt. Refresh recovery,
durable result retrieval, cancellation, and draft recovery are not implemented.
Development's async job and cable adapters are process-local; production worker
and cable configuration require actual deployment verification.

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

The core vocabulary and grammar review workflow is implemented:

    paste Japanese text
        ↓
    Japanese::TextAnalyzer via RubyLLM
        ↓
    review vocabulary and grammar assessments
        ↓
    display prior encounter information
        ↓
    optionally enrich vocabulary with Anki information
        ↓
    learner marks Known / Unknown / Ignore
        ↓
    save encounter history

Next, validate the live analysis loop with real N2 material, fix reliability and
correction gaps, and use several actual study sessions to choose further work.
See [next-steps.md](next-steps.md) for the actionable sequence and acceptance
criteria. Then expand into:

    Study Inbox
        ↓
    grammar history
        ↓
    dictionary enrichment
        ↓
    optional Anki synchronization
        ↓
    personalized AI-generated practice
