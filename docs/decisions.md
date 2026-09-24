# Decision Log

Short records of significant choices. Add a new entry in the same pull request that makes the change. Never rewrite an accepted entry; supersede it with a new one.

Format: number, title, date, status, context, decision, consequences.

---

## 001. Own retry middleware instead of `faraday-retry`

- **Date:** 2026-09-24
- **Status:** Accepted

**Context.** Faraday 2 moved retry support into the separate `faraday-retry` gem. The plan requires Faraday as the only runtime dependency, and payment calls must never be repeated unless it is safe.

**Decision.** Write a small retry middleware inside the gem. It retries only GET requests, or POST requests that carry an idempotency key. At most two retries, with exponential backoff and jitter, on connection errors, 429 and 5xx. On 429 it waits for `Retry-After` when present, up to a cap. A timeout on any other POST raises `CashfreePg::TimeoutError` and is never retried.

**Consequences.** One runtime dependency. The retry rules are fully under our control and covered by our tests. We maintain roughly 60 extra lines of code.

---

## 002. Money is sent as a two-decimal JSON number and parsed as BigDecimal

- **Date:** 2026-09-24
- **Status:** Accepted

**Context.** Cashfree expects amounts as decimal rupee numbers such as `10.10`. Ruby's JSON library serialises a raw `BigDecimal` as the string `"0.101e2"`, and parses decimal numbers as `Float` by default.

**Decision.** `CashfreePg::Money` converts Integer, String and BigDecimal input to a value rounded to two decimal places, and emits it as a plain JSON number at the request boundary. Float input is accepted with a warning. Responses are parsed with `JSON.parse(body, decimal_class: BigDecimal)`.

**Consequences.** Amounts stay exact in both directions. Callers receive `BigDecimal` for amounts in responses.

---

## 003. Default Cashfree API version is 2025-01-01

- **Date:** 2026-09-24
- **Status:** Accepted, to be reconfirmed at the start of Phase 2

**Context.** Several dated API versions are in circulation. Response shapes differ between them.

**Decision.** Pin `2025-01-01` as the default. Callers may override it per client. Before Phase 2 coding starts, confirm it against the latest published OpenAPI specification; if a newer stable version exists, record a superseding entry.

**Consequences.** Changing the default in a later release is a breaking change and is announced in advance.

---

## 004. Minimum Ruby version is 3.3

- **Date:** 2026-09-24
- **Status:** Accepted

**Context.** The plan supports MRI versions still receiving security updates. Ruby 3.2 reached end of life in March 2026.

**Decision.** `required_ruby_version >= 3.3`. CI tests 3.3, 3.4 and the latest stable release.

**Consequences.** Dropping a Ruby version later is a documented minor-release event.

---

## 005. Planning and guide documents live in `docs/`

- **Date:** 2026-09-24
- **Status:** Accepted

**Context.** `doc/` is the default output directory for YARD and is git-ignored.

**Decision.** The project plan, this log and all guides live in `docs/`. `doc/` stays ignored for generated API documentation.

**Consequences.** Nothing hand-written is ever placed in `doc/`.

---

## 006. RBS signatures are maintained from the start

- **Date:** 2026-09-24
- **Status:** Accepted

**Context.** The scaffold created `sig/cashfree_pg.rbs`. Version 1.0 of the plan said RBS would be added only on demand.

**Decision.** Keep `sig/` and update signatures alongside public API changes.

**Consequences.** Slightly more work per pull request. Typed users get accurate signatures from the first release.
