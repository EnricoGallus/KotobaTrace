# KotobaTrace — Milestones

## 0. Clean up

- Remove the MeCab usage

## 1. Validate analysis reliability and quality

- Run real N2 passages, short vocabulary lists, and long inputs through analysis,
  vocabulary/grammar review, and shared saving. Record latency and available
  token/cost data; consider on-demand examples if measurements justify it.
- Exercise delayed replies, Anki unavailable or disabled, disconnects, retries,
  and server restarts. Trace request IDs through job logs and verify browser
  delivery, late results, and rejection of superseded results.
- Build a small, human-reviewed live evaluation set for vocabulary coverage,
  normalization, encountered readings, source-grounded grammar, translations,
  and teaching examples in English, Japanese, German, and Vietnamese. Record
  model, prompt revision, language, date, and remaining errors.
- Include the reported omissions: 部署に移る, 移れた, 強制される, 一瞬驚いた,
  政治的な活動, はるかによい, and 答えが返ってくる. Add negative and ambiguous
  cases to catch incorrect splitting or merging.
- Implement the smallest recovery mechanism supported by observed delivery
  failures, with an explicit lifetime for temporarily retained results.

## 2. Improve corrections and unfinished reviews

- Let learners correct base forms/classifications and remove false extractions
  before saving while preserving source context and existing history.
- Add an unassessed filter that preserves the complete save submission.
- Recover unfinished reviews after refresh or language navigation. Define storage
  and expiry while keeping generated learning details temporary.
- Evaluate a mobile card layout during real phone study.
- Use the app for 5–7 days of actual study; record friction, history usefulness,
  and the largest obstacle to completing a session. Use findings to prioritize work.

## 3. Build the Study Inbox and candidate export

- Rank recurring difficulty using saved passage encounters, recency, and learner
  assessments. Define how Reading only and Meaning only affect ranking and explain
  why each candidate appears. Validate the shortlist against actual study choices.
- Show passage context and history; distinguish Anki membership from knowledge.
- Support marking known, selecting candidates, and learner-approved TSV/CSV export.
- Add a persistent, reversible “Never suggest this word again” preference that
  preserves history and leaves future passage analysis unaffected.
- Add search, difficulty filters, sorting, and server-side pagination through a
  Turbo Frame, preserving query parameters and resetting pages on query changes.
  Evaluate Pagy; add snoozing only if study use warrants it.

## 4. Expand context and grammar review

- Preserve passage layout and let learners inspect vocabulary, readings,
  assessments, and prior contexts without losing their place.
- Add grammar recurrence/history views to identify repeatedly difficult patterns.
  Add correction or manual entry where live evaluation demonstrates a need.

## 5. Add optional enrichment

- Introduce dictionary lookup behind a small provider boundary. Evaluate hosted
  data or focused JMdict integration, including attribution/licensing, readings,
  relevant senses, multilingual meanings, and standalone search.
- Choose portable Anki transport based on deployment needs: import/export,
  snapshots, a local bridge, an add-on, or a companion app. Add deck/field settings.
- Add scheduling/review metadata and explicit note creation with duplicate checks
  if useful. Keep analysis and saving usable when enrichment is unavailable.

## 6. Prepare an invite-only beta

- Add accounts, authentication, ownership scoping, and verified user data isolation
  before inviting testers.
- Deploy with Kamal to a separate host/database; configure HTTPS, secrets,
  production jobs/cable, monitoring, deployment/rollback, and off-machine backups.
- Verify production MeCab dependencies and test backup restoration.
- Add short onboarding and privacy information; verify two invited users can
  complete the study workflow with isolated data.

## 7. Harden for public use

- Add account deletion, rate limits, robust validation/recovery, and accessibility
  and mobile improvements based on closed-beta feedback.
- Extend coverage for critical user journeys and verify onboarding without
  developer assistance.

## Later, guided by study needs

- OCR with editable recognized text, browser/ebook capture, and improved PWA input.
- Hotwire Native iOS/Android features and store releases when demand justifies them.
- Contextual correction assistance and personalized reading exercises or quizzes
  built from difficult vocabulary and grammar in saved history.
- Frequency, pitch accent, audio, and JLPT enrichment where useful data is available.
