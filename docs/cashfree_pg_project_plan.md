# cashfree_pg

## A Ruby Client Library for the Cashfree Payments API

**Project Plan and Phased Implementation Roadmap**

| Item | Detail |
| --- | --- |
| Document version | 1.1 (draft) |
| Date | 24 September 2026 |
| Project type | Open-source Ruby gem, MIT licence |
| Runtime | Ruby 3.3 or newer (MRI versions receiving security updates), Rails optional |
| Current status | Phase 1 (foundation and repository hygiene) complete; Phase 2 not started |
| Planned releases | v0.1.0 (Payments MVP), v0.2.0 (Rails), v0.3.0 (Verification), v1.0.0 (Stable) |

<div style="page-break-after: always;"></div>

## Contents

1. [Executive Summary](#1-executive-summary)
2. [Background and Opportunity](#2-background-and-opportunity)
3. [Vision, Goals and Non-Goals](#3-vision-goals-and-non-goals)
4. [Scope](#4-scope)
5. [Cashfree API Landscape](#5-cashfree-api-landscape)
6. [Architecture and Design Principles](#6-architecture-and-design-principles)
7. [Repository Structure](#7-repository-structure)
8. [Roadmap Overview](#8-roadmap-overview)
9. [Phase-by-Phase Implementation Plan](#9-phase-by-phase-implementation-plan)
10. [Testing Strategy](#10-testing-strategy)
11. [Security Considerations](#11-security-considerations)
12. [Versioning and Release Policy](#12-versioning-and-release-policy)
13. [Risks and Mitigations](#13-risks-and-mitigations)
14. [Path to Official Cashfree Support](#14-path-to-official-cashfree-support)
15. [Success Metrics](#15-success-metrics)
16. [Appendices](#16-appendices)
17. [Changes in Version 1.1](#17-changes-in-version-11)

<div style="page-break-after: always;"></div>

## 1. Executive Summary

`cashfree_pg` is an open-source Ruby gem that gives Ruby and Rails developers a clean, well-tested interface to the Cashfree Payments REST APIs. It is modelled on the developer experience of Razorpay's official Ruby gem, but adapted to how Cashfree's APIs actually work: per-product credentials, multiple API versions, decimal rupee amounts, and timestamp-based webhook signatures.

The gem is strictly an API client. It does not implement UPI, NPCI connectivity, or any payment infrastructure. Every operation is an authenticated HTTPS call to an existing Cashfree endpoint.

**At a glance**

- **Problem:** Cashfree publishes official server-side SDKs for Java, Node, Python, PHP, Go and .NET, but not for Ruby. The one community gem found on RubyGems (`cashfree`, version 0.0.2, June 2023) has not been updated in about three years.
- **Solution:** A small, dependable gem covering Orders, Payments, UPI, Refunds, Payment Links, Webhooks and, later, Bank/UPI verification.
- **Approach:** Ten small phases, each with clear deliverables and exit criteria, released incrementally from v0.1.0.
- **Differentiators:** Instance-based client (thread-safe, multi-merchant), API version pinning, safe money handling, first-class webhook verification, optional Rails integration, and testing helpers for host applications.
- **Long-term aim:** Build enough quality and adoption that Cashfree links to the gem or adopts it as an officially supported Ruby SDK.

## 2. Background and Opportunity

### 2.1 The gap

Ruby on Rails is widely used across Indian startups and agencies, and many of them accept payments through Cashfree. Today those teams either write raw HTTP calls by hand or rely on an unmaintained gem. A hand-rolled integration typically re-implements the same fragile pieces: authentication headers, API version handling, error mapping, and webhook signature checks.

### 2.2 Prior art

| Source | What it offers | Observation |
| --- | --- | --- |
| Cashfree official SDKs | Java, Node, Python, PHP, Go, .NET, and mobile SDKs | No official Ruby server SDK. Ruby appears only as a Rails sample app in the `pg-samples` repository. |
| `cashfree` gem on RubyGems | Community gem, version 0.0.2, June 2023, roughly 1,200 downloads | Effectively abandoned. Not a reliable base to build on. |
| Razorpay Ruby gem (`razorpay`) | Official gem with a broad resource surface, built on HTTParty | Useful reference for ergonomics. Its global `Razorpay.setup` configuration and very wide scope are things this project deliberately avoids. |

One caveat: a Cashfree marketing FAQ claims integration kits exist for Ruby. No Ruby SDK was found behind that claim, so the gap should be reconfirmed with Cashfree before major announcements.

### 2.3 Why a gem is worth more than raw HTTP calls

A raw Faraday call is only a few lines. The value of the gem comes from everything around it:

- Correct, tested authentication and version headers on every request
- A consistent error hierarchy instead of ad hoc status-code checks
- Webhook signature verification done correctly (raw body, constant-time comparison)
- Safe money handling
- Retry and idempotency behaviour that does not duplicate payments
- Rails conveniences and test helpers so host applications write less boilerplate

## 3. Vision, Goals and Non-Goals

### 3.1 Vision

To be the default, trusted way for Ruby developers to integrate with Cashfree Payments, small enough to audit in an afternoon and stable enough to depend on in production.

### 3.2 Goals

| Goal | Measure of success |
| --- | --- |
| Cover the core payment lifecycle | Orders, Payments, Refunds, Payment Links and Webhooks working against the Cashfree sandbox |
| Be safe by default | Secrets never logged; webhook verification uses the raw body and constant-time comparison |
| Be easy to adopt | A working checkout flow in a Rails app in under 30 minutes using the README |
| Be maintainable by one person | Small dependency footprint, high test coverage, documented conventions |
| Track Cashfree's API versions | Version pinning per client and a documented upgrade path |

### 3.3 Non-goals

- Implementing UPI, NPCI connectivity, or any payment-processing infrastructure
- Building a checkout user interface or front-end JavaScript
- Handling raw card numbers in version 1 (Cashfree documents that raw card flows place PCI DSS obligations on the merchant)
- Covering every Cashfree product in version 1 (Payouts, Subscriptions, Easy Split and Settlements are future work)
- Acting as, or being marketed as, an official Cashfree product without their permission

## 4. Scope

| Capability | Included from | Notes |
| --- | --- | --- |
| Client, configuration, errors, retries | Phase 2 | Foundation for everything else |
| Orders (create, fetch) | Phase 3 | Core of the payment flow |
| Payments (fetch, order sessions, pre-authorisation) | Phase 3 | Order sessions are the "Order Pay" call |
| UPI payment helpers | Phase 4 | Payload builders for UPI methods documented by Cashfree |
| Refunds | Phase 5 | Create, fetch, list |
| Payment Links | Phase 5 | Create, fetch, cancel |
| Webhook verification and events | Phase 6 | Header-based HMAC verification |
| Rails integration | Phase 8 | Railtie, generator, controller concern, instrumentation |
| Bank account and UPI verification | Phase 9 | Separate credentials and base URL |

## 5. Cashfree API Landscape

The design of the gem is driven by these documented characteristics of Cashfree's APIs.

| Topic | What the gem must handle |
| --- | --- |
| Authentication | Each request carries `x-client-id`, `x-client-secret` and `x-api-version` headers. |
| Environments | Sandbox base `https://sandbox.cashfree.com/pg`; production base `https://api.cashfree.com/pg`. |
| API versions | Multiple dated versions are in circulation (for example 2022-09-01, 2023-08-01, 2025-01-01 and a 2026-01-01 specification). The gem pins one default and lets callers override it. |
| Per-product credentials | Each Cashfree product (Payment Gateway, Payouts, Verification Suite) needs its own client ID and secret. |
| Verification base URL | Verification Suite uses `https://api.cashfree.com/verification` (sandbox: `https://sandbox.cashfree.com/verification`). |
| Order Pay | The order sessions call does not require `x-client-id` or `x-client-secret` and can be made from the client side. It still requires `x-api-version`. Calling it from a server may require Cashfree's server-to-server (S2S) or seamless feature to be enabled on the merchant account; verify before Phase 3. |
| Money | Amounts are decimal rupee values sent as JSON numbers (for example `10.10`), not integer paise and not strings. |
| Request tracing | Cashfree accepts an `x-request-id` request header. The gem sends a generated value on every call so support tickets can be traced. |
| Verification and Payouts authentication | Besides client ID and secret, these products require either IP allow-listing or an `x-cf-signature` header: the RSA encryption (Cashfree public key, OAEP padding) of `client_id.unix_timestamp`, Base64 encoded. Confirm the exact scheme in the Verification Suite documentation before Phase 9. |
| Rate limits | 429 responses may carry a `Retry-After` header and rate-limit headers. |
| Pagination | Some list endpoints are paginated. The mechanism (cursor or page) must be confirmed per endpoint in the OpenAPI specification. |
| Webhook signature | Base64 of HMAC-SHA256 over the timestamp header concatenated with the raw request body, using the client secret. The timestamp is in milliseconds. |
| Webhook versions | Payload shape depends on the webhook version configured in the dashboard and is sent in the `x-webhook-version` header. Legacy form-encoded webhooks (signature in the body) are out of scope. |
| Idempotency | Some endpoints, such as Payment Links, accept an idempotency key so that timed-out requests can be retried safely. |
| Sandbox limits | For example, Payment Link SMS notifications are sent only in production; the sandbox sends email only. |
| Error bodies | Cashfree error responses carry type, code and message fields. |

## 6. Architecture and Design Principles

### 6.1 Principles

1. **Thin and predictable.** Keep Cashfree's own field names (snake_case JSON). The gem should not invent a second vocabulary.
2. **Instance-based, not global.** Each client holds its own credentials, which is safe for threads and for apps serving multiple merchants. A global convenience helper is optional.
3. **Secrets never in the repository.** Credentials come from arguments or `ENV` at runtime, and are redacted in all logs and error messages.
4. **Minimal dependencies.** Faraday 2.x only at runtime. Retries are implemented by our own small middleware rather than `faraday-retry`, so the rules for which payment calls may repeat live in this gem. Rails is never a runtime dependency.
5. **Fail loudly and specifically.** Typed errors carrying HTTP status, Cashfree code and type, message and request identifier.
6. **Forward compatible.** Unknown fields and unknown webhook event types must not raise errors.
7. **Money is not a float.** Amounts are handled as `BigDecimal` internally, sent as two-decimal JSON numbers, and parsed back as `BigDecimal`.
8. **Zero leakage.** Secrets, tokens and personal data never appear in logs, exception messages, `inspect` output, fixtures or the packaged gem (see Section 11).

### 6.2 Layers

| Layer | Responsibility | Main files |
| --- | --- | --- |
| Configuration | Credentials, environment, API version, timeouts, logger | `configuration.rb` |
| Client | Public entry point that exposes resources | `client.rb` |
| Transport | Faraday connection and middleware (auth, idempotency, errors, logging) | `connection.rb`, `middleware/` |
| Resources | One class per API area (Orders, Payments, Refunds, Payment Links) | `resources/` |
| Webhooks | Signature verification and event objects | `webhooks/` |
| Verification | Separate client for the Verification Suite | `verification/` |
| Rails | Optional integration loaded only when Rails is present | `rails/` |

### 6.3 Target developer experience

```ruby
client = CashfreePg::Client.new(
  client_id:     ENV.fetch("CASHFREE_CLIENT_ID"),
  client_secret: ENV.fetch("CASHFREE_CLIENT_SECRET"),
  environment:   :sandbox,
  api_version:   "2025-01-01"
)

order = client.orders.create(
  order_amount:     "10.10",
  order_currency:   "INR",
  customer_details: { customer_id: "cust_1", customer_phone: "9999999999" },
  order_meta:       { return_url: "https://example.com/return?order_id={order_id}" }
)

order.payment_session_id   # pass this to the front end

client.orders.fetch("order_123").order_status
client.refunds.create(order_id: "order_123", refund_id: "rf_1", refund_amount: "5.00")
```

Webhook verification in a Rails controller:

```ruby
event = CashfreePg::Webhooks.construct_event(
  raw_body: request.raw_post,
  headers:  request.headers,
  secret:   ENV.fetch("CASHFREE_CLIENT_SECRET")
)
```

### 6.4 Key design decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| HTTP library | Faraday 2.x | Flexible middleware, widely used, fits multi-gateway designs |
| Response objects | Lightweight wrapper over the parsed hash. `[]`, `dig` and `to_h` are the primary interface. Dynamic readers are a convenience: they implement `respond_to_missing?` and never shadow core methods (`hash`, `class`, `method`, `object_id`, `send` and similar); such keys are reachable through `[]` only. Also exposes HTTP status and request identifier | No extra dependency, keeps Cashfree's field names, avoids silent key collisions |
| List responses | One `CashfreePg::ListResponse` shape: `data` (array of responses), `next_cursor` (or equivalent) and an `each_page` helper, defined before Phase 5 | Consistent pagination across resources |
| Autoloading | Ruby's built-in `autoload` | Avoids adding a runtime dependency |
| Retries | Own middleware. Only for safe requests: GET, or POST with an idempotency key. Capped at two retries with exponential backoff and jitter, on connection errors, 429 and 5xx. On 429, waits for `Retry-After` when present (capped) | Prevents duplicate charges or refunds; honours Cashfree's rate limits |
| Unknown outcome | A timeout on a POST without an idempotency key raises `CashfreePg::TimeoutError` and is never retried. Documentation tells callers to fetch the order or refund before trying again | The request may already have succeeded |
| Money serialisation | `CashfreePg::Money` converts Integer, String and BigDecimal to a two-decimal value at the request boundary, emitted as a JSON number (never `"0.101e2"`, which is what Ruby's JSON produces for a raw `BigDecimal`). Floats are accepted with a warning. Responses are parsed with `JSON.parse(body, decimal_class: BigDecimal)` | Exact amounts in both directions |
| Request identifier | Every request carries a generated `x-request-id` (UUID), stored on the response and on any raised error | Traceability for support tickets |
| Default API version | `2025-01-01`, confirmed against the latest OpenAPI specification in Phase 2 and recorded in `docs/decisions.md` | Predictable behaviour per release |
| Webhook replay tolerance | Optional, off by default | Cashfree retries may reuse the original timestamp, so a strict window could reject legitimate deliveries |
| Verification Suite | Separate client class, same gem at first, with optional `x-cf-signature` support (public key path supplied by the caller) | Different credentials, base URL and authentication. Split into its own gem later if it grows |
| Base URLs | Fixed per environment. A custom base URL is accepted only when explicitly flagged for testing and must use `https` | Credentials cannot be sent to an unexpected host |

<div style="page-break-after: always;"></div>

## 7. Repository Structure

```
cashfree_pg/
├── .github/
│   ├── workflows/ci.yml              # RuboCop, RSpec, gitleaks, bundler-audit, gem contents check
│   ├── workflows/release.yml         # Trusted publishing to RubyGems
│   ├── ISSUE_TEMPLATE/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── dependabot.yml
├── bin/                              # console (reads sandbox credentials from ENV), setup
├── docs/                             # This plan, decisions.md, guides: api_versions, webhooks, rails, upi, verification
│                                     # (doc/ is reserved for generated YARD output and is git-ignored)
├── examples/                         # Minimal runnable examples
├── lib/
│   ├── cashfree_pg.rb                # Entry point
│   ├── generators/cashfree_pg/install/
│   └── cashfree_pg/
│       ├── version.rb
│       ├── configuration.rb
│       ├── client.rb
│       ├── connection.rb
│       ├── errors.rb
│       ├── response.rb
│       ├── money.rb                  # BigDecimal coercion and JSON-safe serialisation
│       ├── redactor.rb               # Single source of truth for sensitive keys
│       ├── middleware/               # authentication, request_id, idempotency, retry, error_handler, logging
│       ├── resources/                # base, orders, payments, refunds, payment_links
│       ├── webhooks/                 # signature, event
│       ├── verification/             # client, bank_account, upi (Phase 9)
│       ├── rails/                    # railtie, webhook_verification (Phase 8)
│       └── testing/                  # helpers for host applications
├── spec/
│   ├── spec_helper.rb
│   ├── support/
│   ├── fixtures/                     # JSON responses based on Cashfree documentation
│   ├── cashfree_pg/                  # Mirrors lib/
│   └── integration/                  # Sandbox tests, skipped unless credentials are in ENV
├── .env.example                      # Blank placeholders only
├── .gitignore
├── .rspec
├── .rubocop.yml
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── Gemfile
├── LICENSE.txt
├── README.md
├── Rakefile
├── SECURITY.md
├── cashfree_pg.gemspec
└── sig/                              # RBS signatures, maintained from the start
```

## 8. Roadmap Overview

### 8.1 Phases at a glance

Effort figures are indicative focused working days for a single part-time maintainer, not commitments. They include a buffer of about 20% for specification checks, review and unexpected sandbox behaviour.

| Phase | Title | Main outcome | Effort |
| --- | --- | --- | --- |
| 1 | Foundation and Structure | Professional, CI-verified skeleton | 1 to 1.5 days |
| 2 | Core Client Infrastructure | Configuration, transport, money, redaction, errors, retries | 3 to 4 days |
| 3 | Orders and Payments | Create and fetch orders, fetch payments, order sessions | 3.5 days |
| 4 | UPI Support | UPI payload helpers and flows | 2.5 days |
| 5 | Refunds and Payment Links | Refund and link operations, pagination | 2.5 days |
| 6 | Webhooks | Signature verification and event objects | 2.5 days |
| 7 | Documentation, Hardening and First Release | Public release of v0.1.0 | 4 days |
| 8 | Rails Integration | Railtie, generator, controller concern | 3 days |
| 9 | Verification Suite | Bank account and UPI verification, `x-cf-signature` | 4 to 5 days |
| 10 | Stabilisation, Outreach and v1.0 | Stable API and Cashfree conversation | Ongoing |

Total build effort is roughly 26 to 30 focused days, or about six to seven weeks part-time, followed by an open-ended feedback and stabilisation period.

### 8.2 Release milestones

| Release | Contains | Meaning |
| --- | --- | --- |
| v0.1.0 | Phases 1 to 7 | Payments MVP: usable in production by early adopters, API may still change |
| v0.2.0 | Phase 8 | Rails integration |
| v0.3.0 | Phase 9 | Verification Suite |
| v1.0.0 | Phase 10 | Stable public API under semantic versioning |

### 8.3 Dependency flow

```
Phase 1 --> Phase 2 --> Phase 3 --> Phase 4 --+
                           |                    |
                           +--> Phase 5 --------+--> Phase 6 --> Phase 7 (v0.1.0)
                                                                     |
                                                   Phase 8 <---------+
                                                   Phase 9 <---------+
                                                       |
                                                       +--> Phase 10 (v1.0.0)
```

<div style="page-break-after: always;"></div>

## 9. Phase-by-Phase Implementation Plan

Every phase follows the same shape: objective, tasks, deliverables, and exit criteria. A phase is finished only when its exit criteria and the shared Definition of Done (Appendix B) are met.

**Rules that apply to every phase:**

1. **Verify first.** The first task of each phase is to check every endpoint it touches that is marked "Verify" in Appendix A against the current Cashfree OpenAPI specification, then update Appendix A. No code is written against an unconfirmed path, field or header.
2. **Record decisions.** Any significant choice (library, data format, default value, scope change) is added to `docs/decisions.md` in the same pull request.
3. **Zero leakage.** Every phase honours the rules in Section 11 and adds the tests those rules require for the code it introduces.

---

### Phase 1: Foundation and Structure

**Objective.** Turn the scaffold into a professional, CI-verified skeleton so every later phase builds on solid ground.

**Tasks**

- Confirm the gem name is available on RubyGems (confirmed free on 24 September 2026; the only related gem is the abandoned `cashfree` 0.0.2). Minimum supported Ruby is 3.3, the oldest MRI version still receiving security updates (3.2 reached end of life in March 2026). CI covers 3.3, 3.4 and the latest stable release.
- Finalise the gemspec: summary, description, homepage, source code, changelog and bug tracker URIs, and `rubygems_mfa_required`.
- Declare dependencies: Faraday 2.x at runtime; RSpec, WebMock, RuboCop, SimpleCov, YARD and bundler-audit for development.
- Keep the package allow-list tight: the gem ships only `lib/`, `sig/`, `README.md`, `LICENSE.txt` and `CHANGELOG.md`.
- Create the directory skeleton from Section 7 as modules are introduced (empty placeholder files are not committed).
- Configure RuboCop, RSpec and SimpleCov (with a minimum coverage threshold), and a `bin/console` that reads sandbox credentials from `ENV`.
- Add a GitHub Actions workflow (`ci.yml`) on `main`, `dev` and pull requests, running RuboCop and RSpec across Ruby 3.3, 3.4 and the latest release, plus gitleaks over the full history, `bundler-audit`, and the gem contents check.
- Add repository hygiene files: `.gitignore` covering `.env` files, `.env.example`, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, issue and pull request templates, and Dependabot configuration.
- Write a README skeleton with badges, installation, and a placeholder quick start.
- Enable GitHub secret scanning and push protection, and protect `main` so CI must pass before merging.

**Deliverables.** Green CI, loadable gem, complete repository hygiene files.

**Exit criteria.** `bundle exec rake` passes locally and on CI; `require "cashfree_pg"` works; gitleaks finds no credentials anywhere in the repository history; the built gem contains only allow-listed files.

**Effort.** 1 to 1.5 days.

---

### Phase 2: Core Client Infrastructure

**Objective.** Build the transport layer that every resource will share.

**Tasks**

- **Configuration:** client ID, client secret, environment (`:sandbox` or `:production`), API version, open and read timeouts, logger, retry limit and user agent.
- **Client:** instance-based entry point with lazy resource accessors, plus an optional thread-safe global helper (`CashfreePg.configure`).
- **Connection:** Faraday setup with JSON encoding and decoding, timeouts, and a `User-Agent` of the form `cashfree_pg/<version> ruby/<version>`.
- **Middleware:**
  - Authentication headers. `x-api-version` is always sent. `x-client-id` and `x-client-secret` are skippable for calls that do not need them (order sessions); skipping never removes `x-api-version`.
  - Request identifier: a generated `x-request-id` on every request.
  - Optional idempotency key on POST requests.
  - Retry (own implementation) as defined in Section 6.4, including `Retry-After` handling on 429.
  - Error handling that maps responses to typed errors.
  - Logging that prints only method, path, status, duration and request identifier (never headers or bodies). Faraday's built-in logger middleware is never used.
- **Errors:** `CashfreePg::Error` as the base, with `AuthenticationError` (401), `PermissionError` (403: product not enabled, IP not allow-listed), `NotFoundError` (404), `ConflictError` (409: duplicate `order_id`, `refund_id` or `link_id`), `InvalidRequestError` (400), `ValidationError` (422), `RateLimitError` (429), `APIError` (5xx and anything unmapped), `ConnectionError` (network failure before a response) and `TimeoutError` (outcome unknown). Each carries HTTP status, Cashfree code and type, message, request identifier and the raw body. The raw body is redacted in `inspect` and never included in the exception message.
- **Money:** `CashfreePg::Money` with the serialisation rules from Section 6.4, plus JSON parsing with `decimal_class: BigDecimal`.
- **Redactor:** `CashfreePg::Redactor` holding the single list of sensitive keys (Section 11), used by logging, errors and `inspect`.
- **Response wrapper:** as defined in Section 6.4.
- **Safe printing:** `Client` and `Configuration` override `inspect` and `to_s` so the client secret prints as `[FILTERED]`.
- **Transport safety:** TLS verification always on with no option to disable it; redirects not followed; base URL fixed per environment (Section 6.4).
- **Unit tests** for each piece using WebMock.

**Deliverables.** Working internal request pipeline and error mapping.

**Exit criteria.** Every HTTP status class maps to the intended error; a test proves the client secret never appears in logs, exception messages or `inspect` output; retry behaviour is verified for safe and unsafe requests, including that a timed-out POST without an idempotency key raises `TimeoutError` and is not retried; `BigDecimal("10.10")` is sent as a plain JSON number with at most two decimal places, never as a string or in exponent notation; `x-api-version` is present on requests that skip credentials.

**Effort.** 3 to 4 days.

---

### Phase 3: Orders and Payments

**Objective.** Support the heart of the payment flow.

**Tasks**

- **Orders:** create and fetch (`POST /orders`, `GET /orders/{order_id}`), plus any additional order operations the OpenAPI specification defines.
- **Payments:** fetch payments for an order, fetch a single payment, and the order sessions ("Order Pay") call.
- **Order sessions:** implemented without `x-client-id` and `x-client-secret` (but with `x-api-version`), with documentation explaining that this call is designed to be safe from the client side, and that calling it from a server may require the S2S or seamless feature to be enabled on the merchant account. A 403 from this call maps to `PermissionError` with a message pointing to that requirement.
- **Pre-authorisation:** capture or void an authorised payment (`POST /orders/{order_id}/authorization`) as an optional stretch item.
- **Money handling:** use `CashfreePg::Money` from Phase 2 for every amount field (`order_amount` and similar); response amounts are `BigDecimal`.
- **Duplicate order identifiers:** document that a merchant-supplied `order_id` makes order creation safe to repeat, because a duplicate returns `ConflictError`.
- **Fixtures:** capture request and response examples from the OpenAPI specification and documentation.
- **Sandbox integration spec:** create order, fetch order, fetch payments.

**Deliverables.** `client.orders` and `client.payments` with full unit coverage and one sandbox integration test.

**Exit criteria.** The sandbox test passes when credentials are provided and skips cleanly when they are not.

**Effort.** About 3.5 days.

---

### Phase 4: UPI Support

**Objective.** Make UPI payments simple to initiate through Cashfree.

**Tasks**

- Treat UPI as a payment method inside order sessions. Provide payload builders for the UPI modes Cashfree documents (confirm exact channel names and fields in the specification before coding).
- Prioritise intent and QR flows. NPCI has been phasing out collect requests, so the collect builder is added only if Cashfree still documents it for merchants, and is marked as legacy in the guide.
- Support the pre-authorisation variant for UPI (authorise only, with approval and validity window fields).
- Provide light VPA format checking, without over-validating, so the gem does not reject values Cashfree would accept.
- Use Cashfree's published test VPAs for sandbox tests.
- Document mobile intent flows, and the trade-off between polling order status and relying on webhooks.
- State clearly in the documentation that the gem talks only to Cashfree and never to NPCI or any bank.

**Deliverables.** UPI helper methods, UPI guide in `docs/upi.md`, sandbox tests using test VPAs.

**Exit criteria.** A UPI payment can be started and its status observed end to end in the sandbox.

**Effort.** About 2.5 days.

---

### Phase 5: Refunds and Payment Links

**Objective.** Complete the post-payment and link-based collection flows.

**Tasks**

- **Refunds:** create, fetch and list refunds for an order. Refund identifiers are supplied by the merchant, so document how to use them for safe retries.
- **Payment Links:** create (`POST /links`) and fetch (`GET /links/{link_id}`), plus cancel and listing of orders for a link, confirmed against the specification.
- Encode the documented rules: link identifiers are alphanumeric with hyphen and underscore, up to 50 characters; expiry times are ISO 8601 with a time zone offset.
- Support idempotency keys on link creation.
- **Pagination:** implement `CashfreePg::ListResponse` (Section 6.4) for refund listing and link orders, using the mechanism the specification defines for each endpoint.
- **Money:** `refund_amount` and `link_amount` go through `CashfreePg::Money`.
- Document sandbox limitations, such as SMS being sent only in production.

**Deliverables.** `client.refunds` and `client.payment_links`, with tests and fixtures.

**Exit criteria.** A payment link can be created and fetched, and a refund can be created for a paid sandbox order.

**Effort.** About 2.5 days.

---

### Phase 6: Webhooks

**Objective.** Make receiving and trusting Cashfree webhooks safe and easy.

**Tasks**

- **Signature verification:** compute the Base64 of HMAC-SHA256 over the `x-webhook-timestamp` value concatenated with the raw request body, using the client secret, and compare it with `x-webhook-signature` using a constant-time comparison.
- **Raw body only:** the API must accept the unmodified body string. Parsing and re-serialising JSON changes whitespace and field order and breaks verification.
- **Timestamp handling:** the timestamp is in milliseconds. Offer an optional tolerance window, off by default (see Section 6.4).
- **Header normalisation:** `construct_event` accepts a Rails `ActionDispatch::Http::Headers` object, a plain Hash (any key case) or a Rack env (`HTTP_X_WEBHOOK_SIGNATURE` style), and normalises names before lookup.
- **Fail closed:** a missing or empty signature or timestamp header, a non-string body, or any internal error during verification raises `SignatureVerificationError`. The gem never returns an event that was not verified.
- **Event object:** expose event type, event time, data and the `x-webhook-version` header. Provide convenient accessors for the main documented events (payment success, payment failure, user dropped, refund status and others listed in Cashfree's webhook documentation). Accessors are version-aware, with fixtures for each supported webhook version. Unknown event types and unknown versions must parse without error. Legacy form-encoded webhooks are out of scope.
- **Error type:** a dedicated `SignatureVerificationError`.
- **Testing helper:** a method that signs a payload the same way Cashfree does, so host applications can test their own endpoints.
- **Documentation:** guidance on deduplicating events in the host app, responding quickly, and optional IP allow-listing using the addresses Cashfree publishes.

**Deliverables.** `CashfreePg::Webhooks.construct_event`, `CashfreePg::Testing` signing helper, `docs/webhooks.md`.

**Exit criteria.** Tests cover valid signatures, tampered bodies, wrong secrets, missing headers, all three header formats, millisecond timestamps, each supported webhook version and unknown event types.

**Effort.** About 2.5 days.

---

### Phase 7: Documentation, Hardening and First Release (v0.1.0)

**Objective.** Ship the Payments MVP publicly, with documentation good enough that a stranger can succeed without asking questions.

**Tasks**

- Complete the README: installation, configuration, quick start for each resource, error handling, webhooks, and a link to guides.
- Write YARD documentation for every public method so that it renders well on rubydoc.info.
- Write guides in `docs/`: API versions and upgrades, webhooks, UPI, troubleshooting and FAQ.
- Add a minimal runnable example in `examples/`.
- Run the full test suite across all supported Ruby versions and enforce a coverage threshold in CI.
- Run a dependency audit and a manual review of logs and error messages for secret or personal data leakage.
- Confirm thread safety of the client.
- Set up the release workflow using RubyGems trusted publishing, so no long-lived API key needs to exist on a developer machine.
- Update the CHANGELOG, tag `v0.1.0`, publish, and verify installation from RubyGems in a clean environment.
- Announce in relevant Ruby and Indian developer communities, and introduce the project in Cashfree's developer community channel.

**Deliverables.** Published v0.1.0, complete documentation, automated release pipeline.

**Exit criteria.** A new Rails app can install the gem from RubyGems and complete a sandbox order, refund and webhook verification by following only the README.

**Effort.** About 4 days.

---

### Phase 8: Rails Integration (v0.2.0)

**Objective.** Make the gem feel native inside Rails applications, without making Rails a dependency.

**Tasks**

- **Railtie:** load configuration from ENV or Rails credentials, and default the logger to the Rails logger.
- **Instrumentation:** emit `ActiveSupport::Notifications` events around each API request so apps can measure and log calls.
- **Generator:** `rails g cashfree_pg:install` creates an initializer that reads credentials from ENV only.
- **Webhook concern:** a controller module that reads `request.raw_post`, verifies the signature, and exposes the parsed event.
- **Parameter filtering:** the Railtie appends the gem's sensitive keys (Section 11) to `Rails.application.config.filter_parameters`.
- **Multi-version testing:** run the suite against multiple supported Rails versions using a tool such as Appraisal.
- **Guide:** `docs/rails.md` walking through the complete flow: create an order in a controller, hand the session identifier to the front end, handle the return URL by fetching order status, and confirm through the webhook.

**Deliverables.** `cashfree_pg/rails` integration, generator, guide, released as v0.2.0.

**Exit criteria.** The example Rails flow works end to end, and the gem still loads and passes tests with Rails absent.

**Effort.** About 3 days.

---

### Phase 9: Verification Suite (v0.3.0)

**Objective.** Add Bank account and UPI verification without mixing it into the payments client.

**Tasks**

- **Separate client:** `CashfreePg::Verification::Client` with its own credentials, base URL and API version, following the per-product credential model.
- **Two-factor authentication:** support both options Cashfree offers. With IP allow-listing, no extra header is needed. Otherwise the caller supplies Cashfree's public key (path or PEM string, never committed) and the client adds `x-cf-signature` to each request, generated from `client_id` and the current Unix timestamp as documented. A 403 caused by a missing allow-list entry or signature maps to `PermissionError` with a clear hint.
- **Bank account verification:** asynchronous request plus status retrieval, and handling of the verification webhook using the same signature scheme.
- **UPI verification:** UPI penny drop, including a helper that builds the required user consent object.
- **Personal data protection:** redact account numbers, VPAs and names in logs and error messages, and test that redaction works.
- **Documentation:** explain that the Verification Suite must be enabled on the merchant account, that some banks are documented as unsupported, and that obtaining and recording user consent is the merchant's responsibility.
- **Decision point:** if the verification surface grows, split it into its own gem.

**Deliverables.** `client.verification` namespace, tests, `docs/verification.md`, released as v0.3.0.

**Exit criteria.** Sandbox bank and UPI verification succeed using Cashfree's test data, and no personal data appears in any log output during tests.

**Effort.** 4 to 5 days.

---

### Phase 10: Stabilisation, Outreach and v1.0

**Objective.** Convert a working gem into a trusted, stable one, and open the conversation with Cashfree.

**Tasks**

- Collect feedback from early adopters and triage issues with a stated response-time goal.
- Review the public API for anything that should change before it is frozen, and make those changes in 0.x releases.
- Review and complete the RBS signatures in `sig/`, which are maintained alongside the code from Phase 2.
- Open a pull request to Cashfree's `pg-samples` repository updating the Ruby sample to use the gem.
- Contact Cashfree through their developer Discord and their developer support email to discuss linking from their SDK page or an official adoption.
- Publish a short post describing the gem and how to migrate from hand-written integrations.
- Declare v1.0.0 once the API has been stable for a sustained period with no breaking changes pending.

**Deliverables.** v1.0.0, published roadmap for post-1.0 work, documented relationship with Cashfree.

**Exit criteria.** Semantic versioning commitments are documented and the issue backlog contains no known critical defects.

**Effort.** Ongoing.

**Future work after v1.0.** Settlements, Payouts (separate credentials), Subscriptions, Easy Split and marketplace features (partner authentication), reconciliation helpers and additional instrumentation adapters.

<div style="page-break-after: always;"></div>

## 10. Testing Strategy

| Layer | Approach |
| --- | --- |
| Unit tests | RSpec with WebMock. Every resource method is tested against fixtures derived from Cashfree's OpenAPI specification and documentation. |
| Contract checks | Fixtures are refreshed when Cashfree publishes a new API version, and differences are reviewed. |
| Sandbox integration | Tagged tests that run only when sandbox credentials are present in `ENV`, and skip cleanly otherwise. Never run in pull requests from forks. |
| Security tests | One test per Zero Leakage rule (Section 11.2), plus a suite-wide leak check that fails the build if the test secret or fixture PII appears in any captured log or error output. |
| Repository and package checks | gitleaks over the full history, `bundler-audit`, and a check that the built gem contains only allow-listed files. |
| Compatibility | CI matrix across supported Ruby versions and, from Phase 8, supported Rails versions. |
| Quality gates | RuboCop clean, coverage threshold enforced in CI, dependency audit on a schedule. |

**Recorded responses.** If VCR or similar tools are used, authentication headers and personal data must be filtered before a cassette is committed.

## 11. Security Considerations: Zero Leakage Rules

This gem sits in the payment path. A single leaked secret or customer record is a serious incident, so these rules are mandatory, apply to every phase, and each one is enforced by an automated check. A pull request that breaks a rule is not merged.

### 11.1 What must never leak

| Category | Items |
| --- | --- |
| Credentials | Client secret, client ID paired with its secret, Verification Suite private material, RubyGems credentials |
| Tokens and signatures | `payment_session_id`, `x-webhook-signature`, `x-cf-signature`, idempotency keys paired with request bodies |
| Personal data | Customer name, phone, email, VPA, bank account number, IFSC, identity numbers |
| Payloads | Raw request and response bodies, raw webhook bodies |
| Card data | Never handled at all in version 1 |

The key names for these items live in one place, `CashfreePg::Redactor::SENSITIVE_KEYS`, and every redaction path uses it.

### 11.2 Rules and how each is enforced

| # | Rule | Enforced by |
| --- | --- | --- |
| 1 | **Object printing.** `Client`, `Configuration`, `Verification::Client` and error objects override `inspect` and `to_s`; secrets print as `[FILTERED]`. Ruby's default `inspect` prints every instance variable, so it must never be used on these classes. | Spec asserts the secret is absent from `inspect`, `to_s`, `pp` and string interpolation output |
| 2 | **Logging.** The gem's logging middleware prints only HTTP method, path (with identifiers kept, query values redacted), status, duration and request identifier. It never prints headers or bodies at any log level. Faraday's built-in `:logger` middleware is never used. | Spec captures log output at DEBUG for every resource call and asserts no header value, body field or secret appears |
| 3 | **Errors.** Exception messages contain only HTTP status, Cashfree code, type, message and request identifier. The raw body is available as an attribute for callers who need it, and is redacted in `inspect`. Cashfree's own `message` field is passed through the redactor before use. | Spec raises each error type with PII in the response body and asserts `message`, `full_message` and `inspect` are clean |
| 4 | **One redaction list.** `CashfreePg::Redactor` is the only place that knows which keys are sensitive. Adding a field means adding it there, never a local filter. | Spec checks that every key in `SENSITIVE_KEYS` is redacted in nested hashes and arrays; code review rejects ad hoc filters |
| 5 | **Transport.** HTTPS only. TLS certificate verification is always on and there is no option to turn it off. Base URLs are fixed per environment; a custom base URL is accepted only when explicitly flagged for testing and must be `https`. Redirects are never followed, so credentials are never re-sent to another host. | Specs for rejected `http` URLs, rejected unflagged custom URLs, and no redirect following |
| 6 | **Webhooks.** Verification uses the raw body and `OpenSSL.fixed_length_secure_compare` (with a length check first). It fails closed: missing headers, wrong types or any internal exception result in `SignatureVerificationError`. No unverified event object is ever returned. | Specs for tampered body, wrong secret, missing and empty headers, non-string body, and an injected internal error |
| 7 | **Rails.** The Railtie appends `SENSITIVE_KEYS` to `Rails.application.config.filter_parameters` so host application logs are protected too. | Rails integration spec checks the filter list |
| 8 | **Tests and fixtures.** Only fake data (for example `9999999999`, `test@example.com`, `success@upi`). If VCR is ever used, authentication headers and PII are filtered before recording. A suite-wide leak check collects all log output and error text produced during the run and fails if the test secret or any fixture PII appears. | `spec/support` leak-check hook that runs after the suite; fixture review in the Definition of Done |
| 9 | **Repository.** `.env*` files are git-ignored except `.env.example`, which holds blank placeholders only. GitHub secret scanning and push protection are enabled, and `main` is protected so CI must pass. | gitleaks in CI scans the full git history on every push and pull request |
| 10 | **Gem package.** The released `.gem` contains only `lib/`, `sig/`, `README.md`, `LICENSE.txt` and `CHANGELOG.md`. No `.env`, `spec/`, `docs/`, `doc/`, fixtures or CI files are shipped. | CI builds the gem and compares its file list against an allow-list |
| 11 | **CI secrets.** Sandbox credentials exist only as GitHub Actions secrets, are used only on pushes to protected branches, are never exposed to pull requests from forks, and are never echoed. Workflows use `permissions: contents: read` by default and `persist-credentials: false` on checkout. | Workflow review; integration job guarded by branch and event conditions |
| 12 | **Supply chain.** RubyGems MFA is required (`rubygems_mfa_required`). Releases use RubyGems trusted publishing from GitHub Actions, so no long-lived API key exists on any machine. Dependabot keeps gems and actions updated, `bundler-audit` runs in CI and weekly, and `SECURITY.md` explains private vulnerability reporting. | Gemspec metadata check, `release.yml`, scheduled audit job |
| 13 | **Card data.** Version 1 never collects, accepts or transmits raw card numbers, CVV or expiry. Hosted checkout and Cashfree's own components are the recommended path, because raw card flows carry PCI DSS obligations for the merchant. | Scope rule; code review rejects any card field builders |

### 11.3 Data flow

```
App code --> Client --> Redactor-aware middleware --> HTTPS-only transport --> Cashfree API
                             |
                             +--> Logs and errors (redacted, no headers or bodies)

Incoming webhook --> Verify raw body (constant-time) --> valid:   Event
                                                     --> invalid: SignatureVerificationError
```

## 12. Versioning and Release Policy

- **Semantic Versioning.** Before 1.0, minor releases may include breaking changes and will be listed clearly in the CHANGELOG. From 1.0, breaking changes require a major version.
- **Cashfree API versions.** The gem pins a default API version per release, and callers may override it per client. Changing the default is a breaking change and is announced in advance.
- **Deprecations.** Deprecated behaviour emits a warning for at least one minor release before removal.
- **Supported Ruby and Rails versions.** Follow the versions currently receiving security updates. Dropping a version is a documented, minor-release event.
- **Changelog.** Every user-visible change is recorded in `CHANGELOG.md` in the Keep a Changelog style.

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Cashfree changes or retires an API version | Broken calls for users | Version pinning, fixtures refreshed per version, upgrade guide |
| Cashfree releases its own Ruby SDK | Reduced need for the gem | Build the relationship early; offer the gem or its ideas; stay useful through Rails integration and test helpers |
| Low adoption | Wasted effort | Keep scope small, publish early, write excellent documentation, seek listing by Cashfree |
| Single maintainer burnout | Project stalls | Small surface, automation, contributor-friendly documentation, clear scope |
| Credential or personal data leak | Serious harm to users | Redaction tests, secret scanning, no secrets in fixtures |
| Money handling bugs | Wrong charges or refunds | BigDecimal internally, explicit tests for rounding and formatting, warnings on Float |
| Duplicate charges from retries | Financial and trust impact | Retry only safe requests; idempotency keys |
| Product not enabled on merchant account | Confusing errors during Verification | Clear documentation and error messages explaining product enablement |
| Sandbox behaves differently from production | Surprises after launch | Document known differences; encourage staged rollout |
| Timed-out POST with unknown outcome | Duplicate order or refund if the caller blindly retries | `TimeoutError` is never auto-retried; docs say fetch first; merchant-supplied identifiers make duplicates return `ConflictError` |
| Credentials sent to the wrong host | Secret exposure | Fixed base URLs, `https` only, no redirect following |
| Leak through `inspect` or exception output in host app error trackers | Secret or PII exposure in third-party tools | Overridden `inspect` and `to_s`, redacted error messages, tests for each |
| Verification requests rejected for missing IP allow-list or signature | Confusing 403 errors | `PermissionError` with a clear hint; `x-cf-signature` support |

## 14. Path to Official Cashfree Support

There is no formal community SDK programme known at the time of writing, so this is a relationship-building effort, not an application.

1. **Prove value.** Publish v0.1.0 with strong documentation and gather a few real users.
2. **Contribute where they invite it.** Cashfree's `pg-samples` repository has contribution guidelines. Update the Ruby on Rails sample to use the gem.
3. **Use their channels.** Introduce the project through Cashfree's developer Discord and the developer support email listed in their API specification. Ask to be linked from their SDK documentation.
4. **Offer options.** Possible outcomes are being listed as a community SDK, Cashfree adopting or taking over the repository, or Cashfree generating its own SDK from OpenAPI. Any of these is a good result for Ruby developers.
5. **Respect branding.** Do not call the gem official, and do not use Cashfree's logo, without written permission.
6. **Plan for transfer.** Keep the repository structure, licence and contribution history clean so that transfer of ownership or the gem name is straightforward if Cashfree wishes to adopt it.

## 15. Success Metrics

| Metric | Target for the first year (aspirational) |
| --- | --- |
| Adoption | Steady growth in RubyGems downloads; several public projects depending on the gem |
| Quality | Coverage at or above the enforced threshold; no open critical defects |
| Responsiveness | Issues acknowledged within a few days |
| Documentation | New users complete a sandbox flow using the README alone |
| Ecosystem | Ruby sample in Cashfree's `pg-samples` uses the gem; gem is linked from Cashfree documentation |

<div style="page-break-after: always;"></div>

## 16. Appendices

### Appendix A: Planned Endpoint Reference

Paths are relative to the environment base URL. "Confirmed" means the path was seen in Cashfree's documentation while preparing this plan; "Verify" means it must be checked against the OpenAPI specification before implementation. Checking the "Verify" rows is the first task of the phase that uses them (see the rules at the start of Section 9), and this table is updated in the same pull request.

Every call, including order sessions, sends `x-api-version` and `x-request-id`.

**Payment Gateway (base: `https://api.cashfree.com/pg`, sandbox: `https://sandbox.cashfree.com/pg`)**

| Area | Method | Path | Auth headers | Status |
| --- | --- | --- | --- | --- |
| Orders | POST | `/orders` | Yes | Confirmed |
| Orders | GET | `/orders/{order_id}` | Yes | Confirmed |
| Payments | POST | `/orders/sessions` | Not required (`x-api-version` still sent) | Confirmed |
| Payments | POST | `/orders/{order_id}/authorization` | Yes | Confirmed |
| Payments | GET | `/orders/{order_id}/payments` | Yes | Verify |
| Payments | GET | `/orders/{order_id}/payments/{cf_payment_id}` | Yes | Verify |
| Refunds | POST | `/orders/{order_id}/refunds` | Yes | Verify |
| Refunds | GET | `/orders/{order_id}/refunds/{refund_id}` | Yes | Verify |
| Refunds | GET | `/orders/{order_id}/refunds` | Yes | Verify |
| Payment Links | POST | `/links` | Yes | Confirmed |
| Payment Links | GET | `/links/{link_id}` | Yes | Confirmed |
| Payment Links | Cancel and list orders | To be determined | Yes | Verify |

**Verification Suite (base: `https://api.cashfree.com/verification`, sandbox: `https://sandbox.cashfree.com/verification`)**

| Area | Method | Path | Status |
| --- | --- | --- | --- |
| UPI penny drop | POST | `/upi/penny-drop` | Confirmed |
| Bank account verification (async) | POST | `/bank-account/async` | Confirmed |
| Verification status retrieval | GET | To be determined | Verify |
| Two-factor authentication | Header | `x-cf-signature` (or IP allow-listing) | Verify exact scheme |

### Appendix B: Definition of Done (applies to every phase)

A pull request or phase is complete only when all of the following are true:

1. Behaviour is covered by unit tests, including error and edge cases.
2. RuboCop passes and the coverage threshold is met.
3. Public methods have YARD documentation with an example.
4. Fixtures reflect the current Cashfree documentation or OpenAPI specification.
5. No secrets or personal data appear in code, fixtures, logs, `inspect` output or test output, and the Zero Leakage checks (Section 11.2) pass.
6. Any significant decision is recorded in `docs/decisions.md`.
7. The CHANGELOG is updated for any user-visible change.
8. Sandbox integration tests pass where they apply.
9. Documentation in `docs/` or the README is updated.
10. RBS signatures in `sig/` match any public API change.

### Appendix C: Glossary

| Term | Meaning |
| --- | --- |
| Cashfree PG | Cashfree Payment Gateway, the product used to accept payments |
| VRS or Verification Suite | Cashfree's identity and account verification product |
| UPI | Unified Payments Interface, India's instant payment system |
| VPA | Virtual Payment Address, the UPI identifier such as `name@bank` |
| NPCI | National Payments Corporation of India, which operates UPI |
| Order | A Cashfree object representing an amount a customer is asked to pay |
| Payment session ID | Token returned when an order is created and used to start payment |
| Idempotency key | A unique value that lets a request be retried without repeating its effect |
| HMAC | Hash-based message authentication code, used to sign webhooks |
| OpenAPI | A machine-readable API description format that Cashfree publishes |
| PCI DSS | Security standard governing handling of card data |

### Appendix D: References

- Cashfree API authentication: `https://www.cashfree.com/docs/api-reference/authentication`
- Cashfree Payment SDK libraries: `https://www.cashfree.com/docs/api-reference/payments/sdk`
- Cashfree webhook payloads and signatures: `https://www.cashfree.com/docs/api-reference/webhooks/payloads-and-signatures`
- Cashfree Verification Suite endpoints: `https://www.cashfree.com/docs/api-reference/vrs/v2/end-point`
- Cashfree Payment Links API: `https://www.cashfree.com/docs/api-reference/payments/latest/payment-links/create`
- Cashfree sample applications: `https://github.com/cashfree/pg-samples`
- Razorpay Ruby gem (reference for ergonomics): `https://github.com/razorpay/razorpay-ruby`

## 17. Changes in Version 1.1

Version 1.1 closes the gaps found in a senior review of version 1.0. Decisions are recorded in `docs/decisions.md`.

| Area | Change |
| --- | --- |
| Money | Defined JSON serialisation (two-decimal number, never `"0.101e2"`) and `BigDecimal` parsing |
| Retries | Own retry middleware; Faraday stays the only runtime dependency; `Retry-After` honoured on 429 |
| Order Pay | Only credential headers are skipped; `x-api-version` is always sent; S2S enablement documented |
| Errors | Added `PermissionError` (403), `ConflictError` (409), `ValidationError` (422) and `TimeoutError` (unknown outcome) |
| Traceability | Generated `x-request-id` on every request |
| Verification Suite | Two-factor authentication through IP allow-listing or `x-cf-signature` |
| Response wrapper | `[]` and `dig` first; dynamic readers never shadow core methods |
| Pagination | One `ListResponse` shape defined before Phase 5 |
| Webhooks | Version-aware events, header normalisation for Rails, Hash and Rack env, fail-closed verification |
| UPI | Intent and QR prioritised; collect treated as legacy |
| Versions | Default API version pinned to `2025-01-01`; minimum Ruby 3.3; CI on 3.3, 3.4 and latest |
| Security | Section 11 rewritten as thirteen enforced Zero Leakage rules |
| Process | About 20% effort buffer, "verify endpoints first" rule per phase, decision log, RBS maintained from the start |
| Repository | Plan moved to `docs/`; Phase 1 hygiene completed (CI, gemspec, ignore rules, security and contribution files) |

---

*End of document.*
