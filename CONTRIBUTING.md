# Contributing

Thanks for helping improve `cashfree_pg`. This gem sits in payment flows, so correctness and security come before features.

## Before you start

- Read the [project plan](docs/cashfree_pg_project_plan.md), especially Section 6 (design principles) and Section 11 (Zero Leakage Rules).
- For anything larger than a small fix, open an issue first to agree on the approach.
- Report security problems privately, as described in [SECURITY.md](SECURITY.md).

## Setup

```bash
bin/setup
bundle exec rake    # specs, RuboCop and gem contents check
```

## Rules for every pull request

1. **Verify against Cashfree first.** New or changed endpoints, fields and headers must be checked against the current Cashfree OpenAPI specification or documentation. Link the source in the pull request.
2. **Zero leakage.** No real credentials, tokens or customer data anywhere: code, fixtures, tests, logs, commit messages or screenshots. Use fake values such as `9999999999`, `test@example.com` and `success@upi`. New sensitive fields go into `CashfreePg::Redactor`, never a local filter.
3. **Tests.** Cover success, error and edge cases with RSpec and WebMock. Real network calls are blocked in tests.
4. **Money.** Never use `Float` for amounts.
5. **Retries.** Never make a non-idempotent request retryable.
6. **Documentation.** Public methods have YARD docs with an example; update the README or `docs/` when behaviour changes.
7. **Changelog.** Add user-visible changes under `[Unreleased]` in `CHANGELOG.md`.
8. **Decisions.** Record significant choices in `docs/decisions.md`.
9. **Types.** Keep `sig/` in sync with public API changes.

## Commit and branch conventions

- Branch from `dev`; open pull requests against `dev`. `main` receives releases.
- Keep commits focused, with messages that explain why.

## Sandbox integration tests

Integration specs run only when sandbox credentials are present in `ENV` and skip otherwise. Never use production credentials for testing.
