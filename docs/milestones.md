# KotobaTrace — Development Milestones

This roadmap starts from the current application and follows the direction in
[summary.md](summary.md). That document owns the product vision and architectural
principles; this document owns delivery order, progress, and acceptance criteria.
See the [README](../README.md) for setup and current capabilities.

The first target is a personally useful vocabulary workflow for real JLPT N2
study. Grammar, public hosting, OCR, and native apps follow evidence from use.
Previous cumulative estimates and week-by-week schedules have been removed:
they assumed an application that had not yet been built and a different analysis
architecture. Estimate each remaining milestone when its scope is concrete.

## Current baseline

Implemented foundations:

- Rails 8.1, Ruby 4, PostgreSQL, Hotwire, esbuild, Tailwind CSS/DaisyUI, and RSpec.
- Japanese text input, background analysis, Turbo Stream results, and Stimulus
  submission controls, with English and Japanese UI translations.
- `Japanese::TextAnalyzer`, using RubyLLM with a Schematist schema to produce
  grouped vocabulary assessments and grammar assessments with source examples,
  meanings, and contextual explanations.
- `Japanese::MorphologicalAnalyzer`, which wraps MeCab/Natto and returns raw
  `Japanese::Morpheme` objects with morphological metadata and sequence positions;
  this deterministic pipeline remains available but is separate from the current
  user-facing analyzer.
- `Japanese::VocabularyExtractor`, with ordered rules for names/honorifics,
  numbers/counters, time expressions, suru verbs, verbs, and content words.
- Vocabulary candidates retaining the morphemes they came from; the results UI
  currently displays only candidates whose kind is `:vocabulary`.
- Results grouped by base form and part of speech, displaying encountered forms,
  readings, and Anki membership.
- Optional, provider-neutral flashcard lookup through `Flashcards::VocabularyLookup`,
  using `Anki::VocabularyIndex` for Anki and an empty, unchecked collection on failure.
  One provider is selected via environment configuration.
- Explicit saving of `Analysis`, reusable `Word` records, and `WordAssessment`
  records linked to vocabulary choices, plus `GrammarAssessment` records linked
  to grammar-specific choices.
- One encounter per word per saved passage, including prior saved data; repeated
  appearances within a passage do not increment history.
- A prior-passage count in results and an in-place word-history dialog with dates,
  assessment totals, all saved assessments/passages, and optional flashcard note
  details. Opening the dialog preserves unsaved analysis and selections.
- Seeded choices: Ignore, Unknown, Reading only, Meaning only, and Known.
- Service, model, job, request, and view specs; GitHub Actions checks.

Important gaps:

- Flashcard lookup scans the configured Anki deck on each analysis; settings UI,
  snapshots, and other flashcard providers are not implemented. Failed enrichment
  no longer prevents analysis or saving.
- Extracted occurrences remain separate until the job groups them. Saved data
  has one assessment per word per analysis, without individual occurrence
  positions or within-passage counts, by design. The original passage is saved;
  displayed surfaces/readings and flashcard membership remain transient.
- A Study Inbox, dictionary meanings, learner corrections, grammar history views,
  and accounts are not implemented. Current history belongs to the single-user app.

## Analysis boundary for all milestones

```text
Japanese text
    ↓
Japanese::TextAnalyzer
    ↓
RubyLLM + Schematist structured response
    ├──→ grouped vocabulary → WordAssessment
    └──→ grammar constructs → GrammarAssessment
```

The local morphological analyzer and vocabulary rules remain independent,
testable services. Do not treat them as the current user-facing analysis path.

## Milestone 1 — Make the Existing Analysis Workflow Reliable

**Status: in progress; the core screen and analysis pipeline exist.**

### Remaining work

- Exercise extraction against real N2 passages and vocabulary lists. Add focused
  regression examples for useful rule improvements.
- Keep specific extraction rules ahead of generic fallback rules; preserve raw
  metadata and duplicate occurrences through extraction.
- Confirm optional flashcard enrichment during actual study with Anki open and
  closed. The service fallback, “not checked” state, and environment-based
  provider/deck/field configuration are implemented and covered by specs.
- Confirm the implemented blank-input rejection, no-vocabulary guidance, and
  localized failure/retry feedback during real use. Progress now follows terminal
  job results, with request IDs preventing stale updates. Browser specs cover the
  complete workflow and optional flashcard outage notices.
- Continue reviewing context-dependent readings. Encountered readings now remain
  transient and do not initialize dictionary readings. Source-aware suffix,
  compound and contracted-verb grouping has regression coverage; see
  [Vocabulary grouping](vocabulary-grouping.md) for its evidence requirements,
  supported lexical entries and extension process.

### Acceptance criteria

A learner can paste a real passage, receive useful vocabulary candidates, select
assessments, and save the result with Anki either available or unavailable.
Analysis failures are visible and recoverable. Morphological ambiguities are
recorded as limitations rather than patched with learner-specific analyzer rules.

## Milestone 2 — Preserve Encounters and Show Personal History

**Status: passage encounter history and the word dialog are implemented; learner corrections and ranking semantics remain.**

### Implemented behavior

- Build on `Analysis`, `Word`, `WordAssessment`, and `AssessmentChoice`.
- Preserve one word/analysis link and at most one assessment per word per saved
  passage. Count passages, not repetitions inside a passage; no occurrence table
  or repetition counter is required for this workflow.
- Show prior saved passage counts in results. The dialog shows first/last saved
  encounters, per-choice totals, unassessed passages, and the full assessment
  timeline with original passages available on demand.
- Load history in a Turbo Frame inside a native dialog, without navigation or
  changes to current selections. Unsaved analyses are excluded from all counts.
- Include optional live flashcard membership and matching note details. Failure
  or disabled configuration does not prevent access to personal history.

### Remaining work

- Let learners correct mistaken base forms or classifications while preserving
  enough source information to understand a correction.
- Define how nuanced assessment choices contribute to difficulty ranking; keep
  Reading only and Meaning only separate from Known.
- Validate the history dialog during actual study before adding richer detail.

### Acceptance criteria

After saving two passages containing the same word, its history shows two saved
passages and their respective assessments. Repeating the word three times in one
passage still adds one encounter. Opening and closing history preserves the
current unsaved selections. These behaviors are covered by browser/model/request
specs, including a reload and a later third saved passage.

## Milestone 3 — Study Inbox and Candidate Export

**Status: planned. Depends on Milestone 2.**

### Work

- Surface recurring difficulty with a simple, explainable ranking based on
  unknown assessments, repeated encounters, recency, and learner choices.
- Distinguish a word absent from Anki from an existing card repeatedly missed in
  real reading. Anki membership does not imply knowledge.
- Support marking known and selecting candidates for later study.
- TODO: Add a persistent “Never suggest this word again” preference. “Dismiss”
  refers to this same action, not a separate state. Suppressed words stay out of
  the Study Inbox even after later encounters, while existing history remains.
  Provide a way to review and undo this preference. This suppresses inbox
  suggestions; it does not hide words from future passage analysis.
- TODO: Add inbox search, difficulty filters, sorting, and server-side pagination.
  Preserve search/filter/sort parameters across pages, reset to the first page
  when the query changes, and update the inbox through a Turbo Frame. Evaluate
  Pagy for pagination; start with Rails queries for basic search.
- Add snoozing only if real use needs it.
- Export approved candidates as TSV/CSV before implementing direct card creation.
  Include context where available; never automatically create cards for every
  unknown word.

### Acceptance criteria

After several study sessions, the inbox provides a useful shortlist and explains
why each word appears. The learner controls which candidates are exported.
“Never suggest this word again” survives reloads and subsequent encounters;
restoring suggestions makes the word eligible under the normal ranking rules.
Ignoring a word creates no new encounter or assessment for that passage.

## Checkpoint A — Use the Personal MVP

**Status: planned. Complete before expanding into larger features.**

Use the app during 5–7 days of actual reading, grammar-book, and kanji-book study.
Record:

1. Whether opening the app becomes a natural part of study.
2. Friction in pasting, extraction, assessment, and saving.
3. Whether encounter history changes what gets studied next.
4. Whether optional Anki information helps.
5. Whether the inbox is more useful than collecting every unfamiliar word.
6. The single largest obstacle to continued use.

The personal MVP is the working loop:

```text
paste Japanese → AI vocabulary and grammar extraction
    → assess results → save encounters → revisit recurring difficulty
```

Anki and dictionary enrichment can improve this loop, but must not be required
for it. Use checkpoint findings to choose the next feature.

## Milestone 4 — Read and Review Vocabulary in Context

**Status: planned; prioritize according to Checkpoint A.**

Preserve the original passage layout and let learners select vocabulary in it.
Show normalized forms, readings, assessments, prior contexts, and available
optional enrichment without losing their place in the passage.

**Acceptance criteria:** the learner can review an encountered word and its
history without repeatedly switching between a detached table and the source.

## Milestone 5 — Grammar Tracking MVP

**Status: initial AI-assisted extraction and assessment are implemented; real-use
accuracy evaluation and correction tools remain.**

`Japanese::TextAnalyzer` extracts passage-grounded grammar constructs alongside
vocabulary. Each `GrammarAssessment` stores its pattern, source example, meaning,
explanation, and learner choice separately from vocabulary concepts. Validate
the extraction against real study passages and add correction or manual-entry
support if actual use requires it.

**Acceptance criteria:** the learner can identify which grammar patterns recur
in their material and which remain difficult. Explanations and examples must be
reviewable against the original text; unrestricted automatic grammar understanding
is outside this milestone.

## Milestone 6 — Optional Dictionary Enrichment and Search

**Status: planned; move earlier only if study sessions show meanings are essential.**

Introduce a small dictionary boundary, such as `Dictionary::Lookup.call(word)`.
Evaluate a hosted provider or a focused JMdict integration before committing to a
large ingestion system. Keep dictionary source data separate from personal
history, and account for attribution and licensing when choosing a provider.

Add meanings, dictionary readings, and relevant senses to vocabulary review.
Standalone search by Japanese writing/reading, and meaning where practical, can
reuse that boundary. Keep translation structures open to future learner languages.

**Acceptance criteria:** dictionary results enrich personal vocabulary history;
provider failures do not prevent analysis, assessment, or saving.

## Milestone 7 — Portable Anki Integration

**Status: local membership lookup exists; portable integration is planned.**

Keep `Anki::VocabularyIndex` as a small integration boundary. A hosted Rails
server cannot directly access AnkiConnect on a learner's computer.

Choose the smallest useful transport from actual deployment needs: text/CSV
import, a persisted snapshot, a browser-to-local bridge, an Anki add-on, or a
companion application. Support explicit deck/field mapping and matching behavior.

Later, add card/review metadata and learner-approved note creation with duplicate
checks if these save meaningful time. Do not modify Anki's database directly.

**Acceptance criteria:** membership is useful beyond the developer's local setup,
with “not checked” distinct from “not found.” The full study workflow remains
usable without Anki. Card creation, if added, requires a learner action.

## Milestone 8 — Invite-Only Closed Beta

**Status: planned, after Checkpoint A validates the product.**

- Add accounts, authentication, ownership, and per-user query scoping before
  inviting testers. Test that users cannot access or modify each other's texts,
  assessments, occurrences, grammar history, or Anki imports.
- Deploy with Kamal to a separate KotobaTrace host and database. Enchan can
  provide umbrella branding/DNS without sharing its constrained server or users.
- Configure HTTPS, production secrets, background jobs, off-machine PostgreSQL
  backups, basic error/uptime monitoring, and repeatable deployment/rollback.
- Verify production images include the MeCab library and compatible dictionary.
- Provide short onboarding and an appropriate privacy explanation.

**Acceptance criteria:** two invited accounts have verified data isolation,
backups can be restored, and deployment does not disrupt the existing Enchan
site. Failing authorization tests block release.

## Milestone 9 — Public Beta Hardening

**Status: planned, after closed-beta feedback.**

Add account deletion, clear privacy information, robust validation and error
handling, appropriate rate limits, accessibility/mobile improvements, and
operational monitoring. Expand integration/system coverage around proven critical
journeys while retaining focused service specs and CI checks.

**Acceptance criteria:** another learner can onboard and complete the core study
workflow without developer assistance, with tested data ownership and recovery.

## Later milestones — Driven by Study Friction

| Feature | Scope and acceptance criteria |
| --- | --- |
| Book photos / OCR | Use an existing engine; show editable recognized text before analysis. It must save time over typing from a textbook. |
| PWA / mobile web | Improve phone navigation, input, uploads, and appropriate caching. Use it on a phone for a week to identify remaining gaps. |
| Hotwire Native iOS | Reuse Rails screens; add camera, photo picker, share sheet, or other native features only for demonstrated needs. |
| Hotwire Native Android | Reuse the proven server workflow and native interaction concepts when Android demand justifies it. |
| App Store / Play Store | Prepare signing, assets, privacy disclosures, crash reporting, and review only once the native workflow is useful. |
| Contextual disambiguation | Add a layer above vocabulary extraction for context-sensitive corrections; keep raw analysis intact. |
| AI explanations / practice | Use actual difficult words and grammar from history for optional explanations and generated exercises; distinguish generated content from dictionary data. |
| Other enrichment | Frequency, pitch accent, audio, and JLPT summaries need useful presentation and suitable data sources. |
| Browser / ebook capture | Reduce text-entry friction when real use justifies extensions or EPUB support. |

## Recommended Next Action

Complete Milestone 1's remaining real-material validation and reading correctness,
then validate the passage-history workflow and define Milestone 3's inbox ranking. Continue refining extraction from real examples
without moving learner-oriented rules into `MorphologicalAnalyzer`.
