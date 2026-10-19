# KotobaTrace — Next steps

Status reviewed against the code on **2026-10-19**. The core workflow is
implemented; this is the next work queue, not a claim of production readiness.
See [README](../README.md) for setup, [summary](summary.md) for architectural
boundaries, and [milestones](milestones.md) for the longer roadmap.

## What is already delivered

- Structured AI vocabulary and grammar extraction through RubyLLM/Gemini, with
  explicit coverage and normalization instructions for reported omissions.
- English, Japanese, German, and Vietnamese interfaces. One application-language
  selection also controls AI translations and explanations.
- Vocabulary contextual translations and Japanese teaching examples with
  translations. Grammar has a source excerpt plus a separate teaching example.
  Teaching examples are expandable in both tabs.
- Compact, four-column vocabulary review with flashcard status and labeled prior
  encounters inside the base-form/meaning cell. POS remains part of word identity.
- Separate review tabs, one shared sticky Save all action, remaining-assessment
  counts, no automatic tab jumps, and bulk vocabulary assessment below the table.
- Source input that collapses after successful analysis without clearing the text;
  an app bar with language navigation; an in-place word-history dialog.
- Explicit persistence of source and learner assessments; generated vocabulary
  learning details and extra grammar teaching examples remain temporary.
- Error/retry behavior, connection waiting, late-current/stale-request handling,
  and job-stage diagnostics, with browser and application regression coverage.

Recent focused verification: the **56 view/request/browser examples** covering
review and save passed after the compact-table/example changes. This was not a
fresh full-suite/CI run. AI-facing tests use mocked responses; real provider
accuracy, language quality, reliability, and cost need their own evidence.

## 1. Prove the live analysis loop

Finish this before adding another major screen.

- Run short lists, normal passages, and a list comparable to the long N2 example.
  Observe the complete path through analysis, optional flashcard lookup, broadcast,
  visible results, assessment of both tabs, and Save all.
- Follow one request ID through the `analyzing`, `flashcards`, `broadcasting`, and
  `completed` log stages. Record failures at the last completed stage rather than
  assuming that a WebSocket connection means results exist.
- Exercise delayed AI replies, Anki unavailable/disabled, connection loss, retry,
  and server restart. Verify late current results can render after browser timeout
  and older results cannot replace a newer review.
- Measure actual elapsed time and available token/cost information for representative
  inputs. Extraction, translation, and examples currently happen in one request;
  consider generating examples on demand only if measurement shows a useful saving.
- If results are lost after reconnect or navigation, choose the smallest recovery
  mechanism. Consider retrievable job state/results rather than adding more browser
  state flags. Respect the decision not to persist generated learning details to
  the application database; any temporary result retention needs an explicit
  lifetime and storage boundary.

**Done when:** representative live inputs visibly complete or fail recoverably,
both result types save together, latency is understood, and connection-related
failures have a reproducible diagnosis and tested recovery. Do not mark this done
solely because mocked tests pass.

## 2. Establish a small AI quality evaluation set

Start with the actual omissions already reported:

| Source | Expected lexical coverage |
| --- | --- |
| 部署に移る | 部署, 移る |
| 移れた | 移る |
| 強制される | 強制する |
| 一瞬驚いた | 一瞬, 驚く |
| 政治的な活動 | 政治的, 活動 |
| はるかによい | はるかに, よい |
| 答えが返ってくる | 答え, 返る; useful 〜てくる grammar must not replace lexical entries |

Add representative passages and negative cases: punctuation-only input, names,
numbers, ambiguous readings, repeated forms, and expressions that should not be
split or over-merged. Review:

- Lexical coverage and appropriate grouping/normalization.
- Exact source substrings for encountered forms and grammar source excerpts.
- Readings of encountered forms, not substituted dictionary readings.
- Relevant grammar explanations and natural teaching examples.
- Contextually correct translations in the selected language, with fluent review
  for German and Vietnamese as well as English/Japanese where available.

Store expected coverage and a compact human-reviewed result record including
model, prompt revision, language, and date. Keep live evaluations opt-in and
separate from deterministic CI tests; they incur provider use and are variable.
Compare later prompt/model changes against this baseline instead of adding
instructions without checking their effect.

**Done when:** the known omission set and representative passages have reviewed
live outputs, remaining errors are recorded, and future prompt changes can be
compared against that baseline. Prompt examples alone do not satisfy this gate.

## 3. Add learner correction and protect unfinished reviews

Let actual study friction choose the first small slice:

- Allow correcting a mistaken lemma or removing a false extraction before saving.
  Preserve the original source and avoid rewriting existing word history silently.
- Add “Show unassessed” filtering for long reviews; retain the full submission so
  filtering never changes what Save all validates or persists.
- Preserve an unfinished review across accidental refresh or language navigation.
  Define whether recovery is local to the browser or server-side, its lifetime,
  and which temporary fields it retains before implementing storage.
- Keep explicit shared saving and the distinction between Ignore for this passage
  and a future permanent inbox-suppression preference.
- Assess compact mobile cards against the current horizontally scrolling table
  using real phone study, rather than extending the desktop table indefinitely.

**Done when:** a learner can correct a bad extraction and resume an interrupted
review without losing choices, duplicating encounters, or unexpectedly saving
previously temporary translations/examples to the database.

## 4. Use it for several study sessions, then build the Study Inbox

Begin the personal-use checkpoint with the existing workflow. Record the largest
obstacle to finishing a session and whether history helps decide what to study.
Use that evidence to prioritize the correction/recovery work above.

Then implement a small Study Inbox from existing saved encounters:

- An explainable shortlist of repeatedly difficult words with passage context and
  links to history. Treat Reading only and Meaning only separately from Know both.
- Learner selection and TSV/CSV export before direct Anki card creation.
- A reversible “Never suggest again” preference that affects inbox suggestions,
  preserves history, and does not remove vocabulary from later analyses.
- Basic search/filter/sort and pagination as the collection grows.

**Done when:** after several sessions, the inbox produces a useful shortlist and
explains why each item appears. Validate its ranking with actual study choices.
The ranking formula and thresholds are product decisions still to be made.

## Later, according to evidence

Grammar-history views, attributed dictionary enrichment, portable Anki transport,
accounts and isolated ownership, deployment/backup recovery, OCR, and native apps
remain in the milestone roadmap. Complete authentication and ownership scoping
before inviting other users; the current data is single-user. The existing
Docker/Kamal/queue configuration is a foundation, not verified hosted readiness.

The next concrete development task is a reproducible live reliability and quality
check—not another broad UI rewrite. The application is far enough along to learn
more from actual study than from adding speculative features.
