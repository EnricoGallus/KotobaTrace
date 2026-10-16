# KotobaTrace

**Learn the Japanese you actually encounter.**

KotobaTrace is a Japanese study companion built around real reading and study
material. Paste a passage or vocabulary list, review learner-facing vocabulary,
and record what you recognize. The goal is to build a personal encounter history
that helps you choose what to study next, especially words you repeatedly miss.

## Current Status

KotobaTrace is an early, local-development application. The current workflow is:

1. Paste Japanese text and select **Analyze**.
2. Review encountered forms, normalized forms, readings, parts of speech, and
   local Anki membership.
3. Choose Ignore, Unknown, Reading only, Meaning only, or Known for vocabulary.
4. Save the analysis and assessments.

Analysis runs as a background job and updates the results through Turbo Streams.
Progress remains active until the job finishes. Blank input is rejected, failures
keep the original text with a retry action, and empty results explain what to try.
A flashcard lookup failure shows an informational notice without blocking saving.
Results group vocabulary by normalized form and part of speech.

Results show how many saved passages contained each word. Click its base form
for a dialog with first/last encounter dates, assessment totals, every saved
assessment and passage, and available flashcard note details. The current draft
is excluded from history. Repetitions within one passage count once.

A Study Inbox, dictionary meanings, grammar tracking, and user accounts are planned. Current
results include analyzer-derived readings, which can reflect encountered forms
rather than dictionary forms. Automatic Japanese analysis can make mistakes.

Flashcard enrichment is optional and uses one provider at a time. Anki is the
current provider; unavailable connections return an empty, unchecked collection
without preventing analysis or saving. Membership means an expression was found
in the configured deck; it does not mean the learner knows the word.

## Stack

- Ruby 4 / Rails 8.1 / PostgreSQL
- Server-rendered views, Turbo Streams, and Stimulus
- Tailwind CSS, DaisyUI, and esbuild
- MeCab via Natto for morphological analysis
- AnkiConnect for the current local vocabulary lookup
- RSpec; Solid Queue and Kamal configuration for later deployment

Exact Ruby and Node versions are pinned in [.ruby-version](.ruby-version) and
[.node-version](.node-version). JavaScript dependencies use Yarn 1.22.22.

## Development Setup

### Using the dev container

Open the repository in a Dev Containers-compatible editor and rebuild/open it in
the supplied [.devcontainer](.devcontainer/devcontainer.json). It configures Ruby,
Node tooling, PostgreSQL, MeCab with a Japanese dictionary, and Selenium.
The post-create command runs `bin/setup --skip-server`.

Inside the container, ensure assessment choices are seeded, then start the app:

```sh
bin/rails db:seed
bin/dev
```

Open <http://localhost:3000>. `bin/dev` starts Rails and the JavaScript/CSS
watchers. Local Anki access needs the configuration below.

### Running without the dev container

Install the pinned Ruby/Node versions, Bundler, Yarn Classic, PostgreSQL and its
client development libraries, and MeCab with its shared library and a compatible
Japanese dictionary. The analyzer expects IPADIC-style feature columns; the dev
container installs `mecab-naist-jdic`, while CI uses `mecab-ipadic-utf8`.

For a locally running PostgreSQL server, set connection values for your local
role before setup:

```sh
export DATABASE_HOST=localhost
export POSTGRES_USER=your_local_database_role
export DATABASE_PASSWORD=your_local_database_password
bin/setup --skip-server
bin/rails db:seed
bin/dev
```

`bin/setup` installs Ruby and JavaScript dependencies and prepares the database.
The database role needs permission to create the development/test databases.
The explicit seed command also initializes assessment choices on an existing
database. Without `--skip-server`, setup starts the development processes itself.

### Local configuration

| Variable | Purpose | Default |
| --- | --- | --- |
| `DATABASE_HOST` | PostgreSQL host | `db` (the Compose service) |
| `POSTGRES_USER` | Development/test database role | `postgres` |
| `DATABASE_PASSWORD` | Development/test database password | `password` |
| `DATABASE_URL` | Alternative Rails database connection URL | Unset |
| `FLASHCARD_PROVIDER` | Active flashcard provider (`anki` or `none`) | `anki` |
| `ANKI_DECK` | Anki deck scanned for vocabulary (blank disables lookup) | `2026 JLPT N2::新完全マスターN2 - 語彙` |
| `ANKI_EXPRESSION_FIELD` | Note field containing vocabulary expressions | `Expression` |
| `ANKI_CONNECT_URL` | AnkiConnect endpoint reachable from Rails | `http://127.0.0.1:8765` |
| `MECAB_PATH` | Explicit path to the MeCab shared library, if Natto cannot discover it | Unset |

See [config/database.yml](config/database.yml) for database names and environment
configuration. Development uses Rails' default asynchronous job adapter; the
current `Procfile.dev` does not start a separate Solid Queue worker.

### AnkiConnect

For optional Anki enrichment, run Anki Desktop with AnkiConnect enabled.
`Flashcards::VocabularyLookup` scans these defaults:

- Deck: `2026 JLPT N2::新完全マスターN2 - 語彙`
- Expression field: `Expression`

Set `ANKI_DECK` and `ANKI_EXPRESSION_FIELD` to match your collection, or set
`FLASHCARD_PROVIDER=none` to skip flashcard lookup. Matching checks exact
normalized expressions against trimmed field values. The job calls the
provider-neutral `Flashcards::VocabularyLookup` service and uses `in_flashcards`
for transient membership.

The dev container sets `ANKI_CONNECT_URL` to
`http://host.docker.internal:8765`. Ensure that address resolves and AnkiConnect is
reachable from the container; Linux Docker setups may need host-gateway mapping
and appropriate AnkiConnect network configuration. Anki being closed or
unreachable returns unenriched results with “not checked” membership. Successful
lookups distinguish found from absent expressions. Connection, read, and write
timeouts are bounded to 2, 5, and 5 seconds respectively per request. Opening a
word-history dialog performs a fresh lookup and can show matching note IDs,
fields, note types, and tags. Remote field markup is displayed as plain text.
Disabled lookup, inaccessible providers, and checked-but-absent words remain
distinct. Card scheduling and review-history details are not fetched yet.

## Tests and Checks

With the dependencies installed and PostgreSQL configured:

```sh
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
```

The suite includes real MeCab examples, so the native library and compatible
dictionary must be available. Anki integration in the specs uses test doubles;
a running Anki instance is not required for the test suite. Browser system specs
also cover progress, failure/retry, empty results, and saving. Build JavaScript
and CSS before running them (`yarn build` and `bin/rails tailwindcss:build`). The
dev container uses remote Selenium; outside it, install Chrome/Chromium and run
`bundle exec rspec spec/system`.

For the broader local checks configured in [config/ci.rb](config/ci.rb):

```sh
bin/ci
```

This also runs setup, lint, dependency/security checks, and a test-environment
seed check. GitHub Actions configuration lives in
[.github/workflows/ci.yml](.github/workflows/ci.yml).

## How Analysis Is Organized

```text
Japanese text
    ↓
Japanese::MorphologicalAnalyzer (MeCab / Natto)
    ↓
raw Japanese::Morpheme objects
    ↓
Japanese::VocabularyExtractor (ordered rules)
    ↓
learner-facing vocabulary candidates
    ↓
grouped results + Anki lookup → learner assessments → explicit save
```

`MorphologicalAnalyzer` preserves raw morphological information. Vocabulary rules
handle learner-oriented grouping, normalization, and filtering. Candidates retain
their source morphemes, including separate repeated occurrences through extraction.
The current save flow persists one assessment per word per analysis; individual
repetitions are not counted or stored separately. The saved word/analysis links
provide passage encounter counts and the full original passages for history.

Future grammar extraction will branch directly from raw morphemes, since it needs
particles and auxiliaries that vocabulary extraction can group or omit.

## Project Documents

- [Product and architecture summary](docs/summary.md): vision, boundaries, and
  development principles.
- [Development milestones](docs/milestones.md): implemented foundations, remaining
  work, acceptance criteria, and later possibilities.

The immediate focus is real-material extraction review and reading correctness,
followed by a useful Study Inbox. Larger features follow real study feedback.
