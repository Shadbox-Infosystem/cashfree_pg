# Contributing

Thanks for helping improve `cashfree_pg`. This gem sits in payment flows, so correctness and security come before features.

## Before you start

- For anything larger than a small fix, open an issue first.
- Report security problems privately, as described in [SECURITY.md](SECURITY.md).

## Setup

```bash
bin/setup
bundle exec rake    # specs, RuboCop and gem contents check
```

## Rules for every pull request

1. **Verify against Cashfree first.** New endpoints, fields and headers must match the current OpenAPI spec or docs. Link the source.
2. **No leaks.** No real credentials, tokens or customer data in code, fixtures, tests, logs, commit messages or screenshots. Use fake values such as `9999999999` and `test@example.com`.
3. **Tests.** Cover success, error and edge cases with RSpec and WebMock. Real network calls are blocked.
4. **Money.** Never use `Float` for amounts.
5. **No auto-retry on POST.** The gem must not retry a non-idempotent request.
6. **Stay small.** No middleware, request logging or Rails dependency. New endpoints go on an existing resource or a new `Resource` subclass.
7. **Docs.** Short YARD comment on public methods; update the README when behaviour changes.
8. **Changelog.** User-visible changes go under `[Unreleased]` in `CHANGELOG.md`.

## Commit and branch conventions

- Branch from `dev`; open pull requests against `dev`. `main` receives releases.
- Keep commits focused, with messages that explain why.

## Sandbox integration tests

Integration specs run only when sandbox credentials are present in `ENV` and skip otherwise. Never use production credentials.
