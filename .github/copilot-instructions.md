# KotobaTrace development guidelines

- This is a Rails 8.1 application running Ruby 4.
- Prefer conventional Rails solutions.
- Use Hotwire: Turbo Frames, Turbo Streams, and Stimulus.
- Use RSpec for tests.
- Use PostgreSQL.
- Keep service objects small and focused.
- Prefer the smallest change that solves the problem.
- Do not introduce React or another frontend framework.
- Do not introduce new dependencies without explaining why.
- When debugging, identify the cause before rewriting code.
- Preserve existing behavior unless explicitly asked to change it.
- Add or update targeted specs for behavior changes.
- Before broad architectural changes, explain the tradeoffs first.
- Do not generate large amounts of code unless specifically asked.