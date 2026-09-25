## What and why

<!-- What does this change do, and why is it needed? Link the issue if there is one. -->

## Cashfree reference

<!-- Link the Cashfree docs or OpenAPI section this change was verified against, or write "n/a". -->

## Checklist

- [ ] Tests cover success, error and edge cases
- [ ] `bundle exec rake` passes locally
- [ ] No real credentials, tokens or customer data in code, fixtures, logs, screenshots or this description
- [ ] No `Float` used for amounts; no POST is auto-retried
- [ ] Public methods have a short YARD comment; README updated if behaviour changed
- [ ] `CHANGELOG.md` updated for user-visible changes
- [ ] `docs/decisions.md` updated for significant choices
