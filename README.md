# KotobaTrace

Learn the Japanese you actually encounter. Paste Japanese text or vocabulary,
review AI-generated vocabulary and grammar, and save assessments to build your
personal encounter history. Anki enrichment is optional.

Built with Ruby 4, Rails 8.1, PostgreSQL, Hotwire, and RubyLLM/Gemini.

## Development

Open the supplied [dev container](.devcontainer/devcontainer.json), which installs
Ruby, Node, PostgreSQL, MeCab, and Selenium and runs setup. Set `GEMINI_API_KEY`
in the Rails environment, then run:

```sh
bin/setup
```

Open <http://localhost:3000>.

Without the container, install the versions in [.ruby-version](.ruby-version) and
[.node-version](.node-version), Bundler, Yarn 1.22.22, PostgreSQL, and MeCab with
NAIST-jdic. Set `DATABASE_HOST`, `POSTGRES_USER`, and `DATABASE_PASSWORD` for your
local database, then run `bin/setup --skip-server` before the commands above.

For optional AnkiConnect lookup, configure `ANKI_DECK`, `ANKI_EXPRESSION_FIELD`,
and `ANKI_CONNECT_URL` (use `http://host.docker.internal:8765` inside Docker).
Set `FLASHCARD_PROVIDER=none` to disable it.

## Local production image

Create an ignored `.env.production.local` containing `RAILS_MASTER_KEY`,
`KOTOBA_TRACE_DATABASE_PASSWORD`, and `GEMINI_API_KEY`, then run:

```sh
docker compose --env-file .env.production.local -f docker-compose.production.yml up --build -d
```

Open <http://localhost:13000>. Startup prepares and seeds the database; data
persists in Docker volumes. Rebuild with the same command after code changes.

## Checks

```sh
bundle bin/ci
```

MeCab and its dictionary are required; browser specs use Selenium/Chrome.
Run `bin/ci` for the full configured checks. Live AI quality requires separate
validation.

See [milestones](docs/milestones.md) for planned work.
