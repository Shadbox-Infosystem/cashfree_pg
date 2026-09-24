## What and why

<!-- What does this change do, and why is it needed? Link the issue if there is one. -->

## Cashfree reference

<!-- Link the Cashfree docs or OpenAPI section this change was verified against, or write "n/a". -->

## Checklist

- [ ] Tests cover success, error and edge cases
- [ ] `bundle exec rake` passes locally
- [ ] No real credentials, tokens or customer data in code, fixtures, logs, screenshots or this description
- [ ] New sensitive fields are added to `CashfreePg::Redactor`
- [ ] No `Float` used for amounts; no non-idempotent request made retryable
- [ ] Public methods have YARD docs; README or `docs/` updated if behaviour changed
- [ ] `CHANGELOG.md` updated for user-visible changes
- [ ] `docs/decisions.md` updated for significant choices
- [ ] `sig/` updated for public API changes
