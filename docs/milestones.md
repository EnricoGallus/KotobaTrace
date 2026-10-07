# KotobaTrace — Ruby on Rails Development Milestones

> **Working name:** KotobaTrace  
> **Product idea:** A Japanese study companion that tracks vocabulary and grammar encountered in real study material, knows what is already in the learner's Anki deck, and helps decide what is actually worth studying.  
> **Primary implementation:** Ruby on Rails  
> **First target:** A personally useful web app for JLPT N2 study, then a public beta, then optional Hotwire Native mobile apps.

---

## 1. Product principles

KotobaTrace should not start as a full Japanese dictionary, Anki replacement, or AI tutor.

The first useful loop is deliberately small:

1. Paste Japanese text.
2. Identify useful vocabulary in the text.
3. Normalize conjugated forms to dictionary forms.
4. Show readings and English meanings.
5. Compare words with the user's imported Anki vocabulary.
6. Let the user mark words they did or did not know.
7. Remember encounters over time.
8. Surface repeatedly failed vocabulary as study candidates.

The app should **not automatically create an Anki card for every unknown word**. Its value is helping the learner decide which words deserve attention.

Grammar tracking comes after vocabulary tracking works well.

---

## 2. Recommended stack

### Core web application

- **Ruby:** current stable Ruby supported by Rails 8
- **Framework:** Rails 8
- **Frontend:** server-rendered Rails views + Hotwire
  - Turbo
  - Stimulus
- **Database:** PostgreSQL **from day one**, in development, test, and production
- **CSS:** Tailwind CSS or the styling approach already most comfortable to the developer
- **Background jobs:** Solid Queue when asynchronous work becomes useful
- **Tests:** Minitest or RSpec; use whichever keeps the project easiest to maintain
- **System tests:** Capybara + Selenium/Playwright only where they add real value
- **Deployment:** Kamal, once the app is ready for a closed beta
- **Hosting:** a dedicated small server for KotobaTrace rather than the already resource-constrained Enchan host
- **Infrastructure principle:** Enchan can be the umbrella site while EnvoTax and KotobaTrace remain separate applications, databases, users, and deployments

### Initial application creation

Recommended command:

```bash
rails new kotoba_trace --database=postgresql --css=tailwind --javascript=esbuild
```

Rails 8 includes Hotwire/Turbo/Stimulus in a normal application unless explicitly skipped, so no extra Hotwire flag is required.

Using `kotoba_trace` rather than `kotobatrace` gives Rails the application namespace `KotobaTrace`, which matches the product name cleanly.

After generation:

```bash
cd kotoba_trace
bin/rails db:create
bin/dev
```

Do not add authentication, OCR, AnkiConnect, or mobile code during application creation. Add them only at the milestone where they become necessary.

### Japanese language data

- **Dictionary:** JMdict
- **Kanji data later:** KANJIDIC2 if needed
- **Morphological analysis:** evaluate an existing Japanese analyzer rather than writing one
  - MeCab
  - Sudachi
  - another maintained tokenizer with reliable lemma/base-form output

The application should hide the chosen analyzer behind a very small Ruby interface such as:

```ruby
Japanese::Tokenizer.call(text)
```

The rest of the application should not depend on analyzer-specific output.

### Anki

Initial integration:

1. Import an Anki text/CSV export.
2. Later support AnkiConnect on desktop.
3. Do not modify the Anki database directly.

### Mobile later

- Responsive Rails/Hotwire web app first
- PWA improvements if useful
- **Hotwire Native** for iOS and Android only after the web workflow is proven
- Native camera/OCR/share-sheet functionality added only where it materially improves the product

---

# Milestone 0 — Technical Spike: Can We Reliably Extract Vocabulary?

**Estimated effort: 4–8 hours**

## Goal

Prove the most uncertain technical part before creating the application architecture:

> Can existing Japanese NLP tooling take real N2 text and return useful dictionary forms?

## Work

Create a small Ruby script or isolated Rails console experiment that:

1. accepts Japanese text;
2. tokenizes it;
3. returns:
   - surface form;
   - dictionary/base form;
   - reading where available;
   - part of speech;
4. filters obvious punctuation and particles;
5. performs a JMdict lookup for several tokens.

Test it with actual sentences from:

- N2 reading material;
- grammar books;
- kanji books;
- ordinary Japanese prose.

Examples to verify:

```text
促した      → 促す
言われている → 言う
著しかった   → 著しい
読まなければ → 読む
```

Also test compounds and nouns such as:

```text
社会保障
劣等感
高齢化
```

## Deliverables

- `Japanese::Tokenizer` prototype
- sample output for at least 20 real sentences
- short decision note explaining which tokenizer was chosen and why

## Acceptance criteria

- Common inflected verbs/adjectives resolve to useful dictionary forms.
- Output is good enough that the user would rather continue developing than abandon the idea.
- No custom tokenizer is written.

## Do not build yet

- UI
- authentication
- Anki integration
- grammar recognition
- OCR
- mobile application

---

# Milestone 1 — Rails Skeleton and First Text Analysis Screen

**Estimated effort: 6–10 hours**  
**Cumulative: 10–18 hours**

## Goal

Create the first app that can be used during an actual study session.

## Work

Create the Rails application with:

- PostgreSQL
- Hotwire
- basic responsive layout
- one main text-analysis screen

The user can paste Japanese into a textarea and press **Analyze**.

The result page should display meaningful vocabulary such as:

| Word | Reading | Meaning |
|---|---|---|
| 著しい | いちじるしい | remarkable; considerable |
| 促す | うながす | to urge; to prompt |
| 制度 | せいど | system; institution |

Each result should retain:

- original surface form;
- dictionary form;
- reading;
- part of speech;
- selected JMdict meanings.

## Suggested code boundaries

```text
app/services/japanese/tokenizer.rb
app/services/dictionary/lookup.rb
app/models/...
```

Keep these interfaces small. Avoid introducing generic repository/factory/framework abstractions.

## Acceptance criteria

During a real N2 reading session:

1. paste a paragraph;
2. analyze it;
3. get useful dictionary-form vocabulary and meanings.

The first version does **not** have to know which words the user knows.

---

# Milestone 2 — Study Texts and Encounter Tracking

**Estimated effort: 8–14 hours**  
**Cumulative: 18–32 hours**

## Goal

Make KotobaTrace remember study history.

## Minimal data model

Possible models:

```text
StudyText
DictionaryEntry
Encounter
KnowledgeMark
```

Do not over-model dictionary data if it can be represented more simply.

An encounter should record enough information to answer:

- Where did I see this word?
- When did I see it?
- Did I know it?
- What sentence/context did it occur in?

## User actions

For each relevant word:

- **Knew it**
- **Didn't know**
- **Ignore**

Example:

```text
促す【うながす】
to urge; to prompt

[ Knew it ] [ Didn't know ] [ Ignore ]
```

After marking:

```text
促す
Encountered: 3
Didn't know: 2
Last seen: 2026-10-12
```

## Add a basic dashboard

Example sections:

```text
Repeatedly difficult

促す      5 encounters / 4 failures
遂げる    4 encounters / 3 failures
伴う      7 encounters / 3 failures
```

## Acceptance criteria

After several study sessions, the app can answer:

> Which words have repeatedly caused me trouble?

This is the first milestone where KotobaTrace becomes meaningfully different from a normal dictionary.

---

# Milestone 3 — Anki Vocabulary Import and Membership Check

**Estimated effort: 8–14 hours**  
**Cumulative: 26–46 hours**

## Goal

Solve one of the core user problems:

> I found a word I don't know. Is it already somewhere in my Anki deck?

## First implementation

Support import of a UTF-8 Anki text/CSV export.

The import flow should allow the user to map fields:

```text
Japanese expression → field 1
Reading             → field 2 (optional)
Meaning             → field 3 (optional)
```

Normalize imported expressions so comparisons work reliably.

Store an Anki vocabulary snapshot.

## Analysis UI

Each word now displays:

```text
促す【うながす】
✓ In Anki
Encountered: 4
Didn't know: 3
```

or:

```text
遂げる【とげる】
✗ Not found in Anki
Encountered: 4
Didn't know: 3
```

## Important behavior

Do **not** equate:

```text
in Anki = known
not in Anki = unknown
```

These are separate facts.

## Acceptance criteria

Using the user's actual deck, a word encountered while reading can reliably be classified as:

- found in imported Anki vocabulary;
- not found in imported Anki vocabulary.

False matches should be uncommon enough that the feature is trustworthy.

---

# Milestone 4 — Study Inbox and Candidate Ranking

**Estimated effort: 6–10 hours**  
**Cumulative: 32–56 hours**

## Goal

Prevent uncontrolled Anki-card creation.

Create a **Study Inbox** containing words worth reconsidering.

## Candidate ranking

Start with deterministic rules, for example:

- number of failed encounters;
- number of total encounters;
- recency;
- whether the word is already in Anki.

Do not use AI or machine learning.

Example:

```text
High priority

遂げる
4 encounters
3 failures
Not in Anki

促す
5 encounters
4 failures
Already in Anki
```

A word already in Anki but repeatedly failed should be surfaced as a different problem:

> Existing card may not be transferring to real reading.

## Actions

- Add to candidate list
- Mark as known
- Ignore
- Snooze/review later

For the first version, “Add to Anki” can simply mean **export candidate data as TSV/CSV**.

## Acceptance criteria

After a week of real study, the app produces a shortlist that feels substantially more useful than creating a card for every unknown word.

---

# Checkpoint A — Stop and Use It

**Estimated effort: 0 development hours; 5–7 days of real usage**

This checkpoint is mandatory.

Do not immediately continue building.

Use KotobaTrace during actual:

- N2 reading;
- grammar-book study;
- kanji-book study.

Collect friction points.

Questions to answer:

1. Do I naturally open KotobaTrace while studying?
2. Is pasting text too slow?
3. Are tokenization results trustworthy?
4. Does Anki membership save time?
5. Does encounter history change what I choose to study?
6. Which screen feels unnecessary?
7. What is the single biggest obstacle to daily use?

Continue only after answering these from real use.

---

# Milestone 5 — Better Reading Experience

**Estimated effort: 10–18 hours**  
**Cumulative: 42–74 hours**

## Goal

Move from a vocabulary table toward a real reading companion.

## Work

Preserve and render the original passage.

Allow vocabulary to be selected in context:

```text
この制度を維持するためには、
住民の理解を促す必要がある。
```

Selecting `促す` shows:

```text
促す【うながす】
to urge; to prompt

Anki: No
Encounters: 3
Failures: 2

[ Knew ] [ Didn't know ]
```

Save the actual encounter sentence/context.

A word detail page should show previous contexts:

```text
住民の理解を促す必要がある。
政府は企業に対応を促した。
```

## Acceptance criteria

The learner can read/analyze a passage without constantly jumping between a result table and the original text.

---

# Milestone 6 — Vocabulary Search / Dictionary Mode

**Estimated effort: 6–12 hours**  
**Cumulative: 48–86 hours**

## Goal

Make the same app useful when the learner wants to look up only one word.

## Work

Add search supporting:

- Japanese word;
- kana;
- English meaning where practical.

A dictionary entry should show:

- writing;
- reading;
- relevant JMdict senses;
- part of speech;
- personal encounter history;
- Anki status.

This is not intended to out-feature Jisho.

Its advantage is personalized study context.

## Acceptance criteria

For a word already encountered, KotobaTrace's entry is more useful to the learner than a generic dictionary page because it includes personal history.

---

# Milestone 7 — Grammar Tracking MVP

**Estimated effort: 15–25 hours**  
**Cumulative: 63–111 hours**

## Goal

Begin solving the second major problem: grammar patterns that repeatedly fail to stick.

## Important scope decision

Do not attempt unrestricted automatic grammar understanding.

Start with a curated set of grammar patterns, initially N2-focused.

Possible data:

```text
GrammarPattern
GrammarEncounter
GrammarKnowledgeState
```

Possible states:

```text
New
Recognize
Understand
Can use
Difficult
```

## Initial workflow

Users can manually record a grammar point from material:

```text
〜ざるを得ない
〜わけではない
〜に伴って
```

Then add automatic pattern detection for grammar where reliable matching rules can be written.

Example:

```text
高齢化に伴って社会保障費が増加している。
```

Recognize:

```text
〜に伴って
N2
encountered: 4
marked difficult: 2
```

## Acceptance criteria

The app can answer:

> Which N2 grammar patterns do I repeatedly encounter but still struggle with?

Manual marking is acceptable before automatic detection is comprehensive.

---

# Milestone 7.5 — Closed-Beta Infrastructure

**Estimated effort: 6–12 hours**  
**Cumulative: 69–123 hours**

## Goal

Make the already-proven personal MVP safely reachable by a very small group of invited testers.

Do this **only after** Checkpoint A shows that the app is genuinely useful in daily study.

## Hosting model

Keep the Enchan website as the umbrella/portfolio site, but do not place KotobaTrace on the existing resource-constrained Enchan EC2 instance.

Preferred layout:

```text
enchan.example
    └── existing Enchan deployment

kotobatrace.enchan.example
    └── separate KotobaTrace host
        ├── Rails
        ├── PostgreSQL
        └── Solid Queue
```

The applications may share branding and DNS while remaining operationally independent.

## Server sizing

For a closed beta, start with roughly a **2 GB RAM-class VM** rather than the smallest possible instance. Kamal deploys can temporarily need additional memory/CPU headroom while old and new containers overlap.

The goal is reliability, not maximum density.

## Deployment

Use Kamal because it is already familiar.

Set up:

- production secrets outside the repository;
- HTTPS;
- PostgreSQL;
- automated off-machine PostgreSQL backups;
- basic uptime/error monitoring;
- a repeatable deploy process;
- a rollback procedure.

## Accounts

Closed beta should be invite-only initially.

Do not build:

- subscriptions;
- teams;
- social login unless genuinely needed;
- shared Enchan authentication.

KotobaTrace users belong only to KotobaTrace.

## Acceptance criteria

- The app is reachable through `kotobatrace.<enchan-domain>`.
- A deploy does not destabilize the existing Enchan site.
- PostgreSQL survives application redeploys.
- Backups are stored off the application server.
- At least two test accounts are verified to have fully isolated data.
- A failed authorization test prevents release.

---

# Milestone 8 — Production Hardening and Public Beta

**Estimated effort: 15–25 hours**  
**Cumulative: 84–148 hours**

## Goal

Move from a personal tool to something another learner can safely use.

## Work

Add:

- user accounts;
- authentication;
- **strict per-user data ownership and query scoping**;
- authorization tests proving that one user cannot read or modify another user's study texts, encounters, Anki imports, or grammar history;
- onboarding;
- account deletion;
- basic privacy policy;
- robust validation/error handling;
- rate limiting where appropriate;
- database backups;
- production logging;
- monitoring;
- accessibility pass;
- responsive/mobile UI pass.

Testing:

- service/model tests for tokenizer normalization and ranking;
- integration tests for main study flow;
- a few system tests for critical user journeys.

CI/CD:

- GitHub Actions
- test suite
- lint/static checks
- deployment pipeline

## Onboarding should stay short

1. Create account.
2. Optional Anki import.
3. Paste Japanese.
4. Analyze.
5. Mark vocabulary.

## Acceptance criteria

A learner who did not build the software can sign up and complete the main workflow without developer assistance.

---

# Milestone 9 — Book Photo / OCR Workflow

**Estimated effort: 12–24 hours for web-first implementation**  
**Cumulative: 96–172 hours**

## Goal

Reduce the biggest friction for physical textbooks.

## Web-first workflow

```text
Take/upload photo
      ↓
OCR
      ↓
editable recognized text
      ↓
Analyze
```

Use an existing OCR engine/service. Do not implement OCR.

The user must always be able to correct OCR mistakes before analysis.

## Important UX target

From opening the camera to seeing analyzed Japanese should take only a few interactions.

## Acceptance criteria

Using a phone with an N2 textbook is meaningfully faster than manually typing/copying difficult sentences.

---

# Milestone 10 — Direct AnkiConnect Integration

**Estimated effort: 10–18 hours**  
**Cumulative: 112–202 hours**

## Goal

Improve desktop Anki awareness and export.

## Capabilities

When AnkiConnect is available:

- find notes/cards;
- determine whether an entry already exists;
- optionally retrieve useful card/review metadata;
- create a note from an approved study candidate;
- avoid duplicates.

Do not make AnkiConnect mandatory.

Web/mobile users must still be able to use KotobaTrace without it.

## Later insight

This enables potentially valuable analysis:

```text
伴う

Anki:
mature card
interval: 42 days

KotobaTrace:
7 real encounters
4 recognition failures

Possible issue:
the card is not transferring well to reading.
```

## Acceptance criteria

Direct Anki functionality saves meaningful time without making KotobaTrace dependent on Anki being online.

---

# Milestone 11 — PWA / Mobile-Web Polish

**Estimated effort: 6–12 hours**  
**Cumulative: 112–202 hours**

## Goal

Find out how far the Rails web application can go before native apps are necessary.

## Work

- installable PWA where appropriate;
- mobile-first navigation;
- camera/upload shortcuts;
- faster text-entry flow;
- sensible caching;
- offline-friendly static assets;
- study sessions comfortable on a phone.

## Acceptance criteria

Use the app from a phone for a week.

Document exactly what still feels materially worse than a native app.

Only those gaps justify Hotwire Native work.

---

# Milestone 12 — Hotwire Native iOS

**Estimated effort: 20–40 hours for first polished version**  
**Cumulative: 132–242 hours**

## Goal

Ship an iOS wrapper because there are proven native needs.

## Keep most screens server-driven

Continue using Rails/Hotwire for:

- text analysis;
- vocabulary pages;
- grammar pages;
- study inbox;
- account/settings.

Add native behavior only for justified features such as:

- camera;
- photo picker;
- share sheet;
- native navigation enhancements;
- secure local settings;
- notifications if later useful.

## Acceptance criteria

The native app provides a meaningfully better book-study workflow than Safari/PWA.

Do not publish merely to claim an App Store presence.

---

# Milestone 13 — Hotwire Native Android

**Estimated effort: 15–30 hours after iOS architecture is established**  
**Cumulative: 147–272 hours**

## Goal

Bring the proven native workflow to Android.

Reuse the same Rails application and interaction concepts.

Native Android-specific work should stay small.

## Acceptance criteria

Feature parity for core study flow, with platform-native behavior where needed.

---

# Milestone 14 — App Store / Play Store Release

**Estimated effort: 10–20 hours initially**

This includes engineering/release work, not store-review waiting time.

## Work

- app metadata;
- screenshots;
- privacy disclosures;
- icons;
- signing;
- store builds;
- crash reporting;
- release checklist;
- handling review feedback.

## Acceptance criteria

The app can be installed by normal users without development tooling.

---

# Optional Later Milestones

These should be driven by actual user requests rather than planned now.

## Frequency information
**Estimate: 8–20 hours**

Depends mostly on finding appropriately licensed data and designing useful presentation.

## Pitch accent
**Estimate: 10–25 hours**

Technical implementation is manageable; trustworthy/licensable data is the larger issue.

## Audio
**Estimate: 10–30+ hours**

Again, sourcing/licensing is likely harder than the code.

## JLPT dashboard
**Estimate: 10–20 hours**

Example:

```text
N2 vocabulary encountered this month
N2 grammar repeatedly failed
recently improved items
```

Avoid pretending JLPT vocabulary lists are perfectly standardized.

## Browser extension
**Estimate: 20–40 hours**

Send selected Japanese text from websites into KotobaTrace.

## EPUB / ebook workflow
**Estimate: 20–50+ hours**

Scope depends heavily on copyright-safe handling and file formats.

## AI explanations
**Estimate: 10–25 hours for a useful first integration**

Examples:

- explain a grammar construction in this sentence;
- compare two similar words;
- explain why a conjugated form became this lemma.

AI should remain optional. The durable value of KotobaTrace is the user's encounter history and study state.

---

# Suggested schedule for the immediate N2 goal

Assumption:

- solo developer;
- already comfortable with Ruby/Rails;
- development alongside normal work and JLPT study;
- approximately 8–12 development hours per week.

## Week 1

**Milestone 0 + Milestone 1**

Target:

```text
paste Japanese
→ tokenize
→ dictionary lookup
→ useful results
```

Estimated: **10–18 hours**

## Week 2

**Milestone 2**

Target:

```text
mark known/unknown
→ save encounters
→ show repeatedly difficult words
```

Estimated: **8–14 hours**

## Week 3

**Milestone 3**

Target:

```text
import actual Anki vocabulary
→ show IN ANKI / NOT IN ANKI
```

Estimated: **8–14 hours**

## Week 4

**Milestone 4 + cleanup**

Target:

```text
Study Inbox
→ prioritize recurring failures
→ export candidates
```

Estimated: **6–10 hours plus fixes**

### Result after roughly 3–4 weeks / 32–56 engineering hours

KotobaTrace should already be capable of helping with daily N2 study:

```text
paste textbook/reading text
          ↓
identify vocabulary
          ↓
compare with Anki
          ↓
mark recognition failures
          ↓
remember them
          ↓
surface useful study candidates
```

Stop there temporarily and use it.

Do **not** rush into grammar, OCR, or native apps before validating this loop.

---

# Complexity and risk assessment

## Low-risk

- Rails CRUD/application structure
- PostgreSQL persistence
- Hotwire interactions
- encounter tracking
- deterministic candidate ranking
- Anki CSV/text import

## Medium-risk

- reliable JMdict import/search
- matching Anki fields consistently
- good tokenizer normalization
- vocabulary highlighting inside original text
- grammar-pattern recognition

## Higher-risk / later

- OCR quality across book layouts
- native app polish
- direct Anki integration across platforms
- automatically identifying arbitrary grammar constructions
- dictionary/audio/pitch datasets with suitable licenses

The project should be structured so failure in any later area does not compromise the core application.

---

# Suggested Rails domain model — initial only

Do not create every model on day one.

A likely progression:

## Milestone 2

```text
users                 # only when accounts are actually needed
study_texts
dictionary_entries
encounters
```

Possible encounter fields:

```text
dictionary_entry_id
study_text_id
surface_form
context
occurred_at
knowledge_result   # knew / did_not_know / ignored
```

## Milestone 3

```text
anki_imports
anki_entries
```

## Milestone 7

```text
grammar_patterns
grammar_encounters
```

Keep raw JMdict data conceptually separate from user-owned learning state.

---

# Architecture rules

1. **No premature service framework.**  
   A few explicit Rails service objects are preferable to a custom application framework.

2. **Keep NLP behind an interface.**  
   Switching from MeCab to another analyzer should not require rewriting the study domain.

3. **JMdict is source data, not user state.**  
   Dictionary updates should not endanger encounter history.

4. **Anki is an integration, not the source of truth.**  
   KotobaTrace's unique value is real-world encounter history.

5. **Do not infer certainty that does not exist.**  
   “Found in Anki” is not the same as “known.”

6. **Do not automatically create cards.**  
   The learner should remain in control.

7. **Prefer deterministic behavior before AI.**  
   Add AI only where it genuinely improves a proven workflow.

8. **Web first. Native only for proven native needs.**

9. **Use the app during development.**  
   Every milestone after the MVP should be justified by real study friction.

10. **Optimize for shipping and understanding.**  
    If a piece of architecture cannot be explained simply, it is probably too early.

11. **PostgreSQL from the beginning.**  
    Development, test, and production should use the same database family; do not add a SQLite-to-PostgreSQL migration project later.

12. **Umbrella branding does not imply shared infrastructure.**  
    Enchan can link to EnvoTax and KotobaTrace while each application keeps its own deployment, database, users, and security boundary.

---

# What counts as the real MVP?

The MVP is **not**:

- public hosting;
- multi-user authentication;
- grammar detection;
- OCR;
- native apps;
- App Store release;
- AI explanations;
- direct AnkiConnect integration.

The real MVP is complete when this works well:

```text
Paste Japanese
      ↓
Tokenize + normalize
      ↓
Dictionary lookup
      ↓
Compare with imported Anki vocabulary
      ↓
Mark "knew / didn't know"
      ↓
Remember encounters
      ↓
Show repeatedly difficult words
```

**Estimated MVP effort: approximately 26–46 hours.**

Adding the Study Inbox and basic candidate ranking brings the more polished personal MVP to roughly:

**32–56 hours.**

For a developer already experienced with Rails, that is a realistic target if tokenizer/JMdict integration behaves reasonably.

---

# Portfolio milestones

For the 2027 job search, the strongest progression is not the number of technologies used. It is the evidence that the project became a real product.

## Strong portfolio point 1

Personal MVP:

> Designed and implemented a Rails application using Japanese morphological analysis and JMdict to identify vocabulary from authentic Japanese study material.

## Strong portfolio point 2

Anki-aware study model:

> Built a personalized encounter model that distinguishes Anki membership from actual recognition failures.

## Strong portfolio point 3

Production beta:

> Deployed a multi-user Rails application with PostgreSQL, authentication, tests, CI/CD, privacy controls, and real users.

## Strong portfolio point 4

Native client:

> Extended the server-driven Rails product to iOS/Android using Hotwire Native and native camera/share-sheet integration.

That tells a much stronger engineering story than adding frameworks solely to a résumé.

---

# Recommended next action

Do **Milestone 0 only**.

Do not generate the Rails app yet.

Take 20–30 real sentences from the N2 material currently being studied and determine whether an existing morphological analyzer can turn them into sufficiently useful dictionary forms.

If that works, create the Rails application and move to Milestone 1.

If it does not, solve or rethink that one problem before investing in the rest of the product.
