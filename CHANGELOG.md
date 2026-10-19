# Changelog

All notable changes to this project are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

First release, 0.1.0. Rename this heading to `## [0.1.0] - YYYY-MM-DD` in the commit that is tagged `v0.1.0`.

### Added

- `CashfreePg::Client`: one instance per merchant, sandbox or production, pinned API version `2025-01-01`, client secret hidden in `inspect`, `to_s`, `pp` and error messages.
- HTTPS only, TLS verified, no redirects, no request logging and no automatic retries. A timed-out POST raises `TimeoutError` telling you to fetch before retrying.
- Typed errors for HTTP 400, 401, 403, 404, 409, 422, 429 and 5xx, plus `ConnectionError` and `TimeoutError`, each with the Cashfree request id.
- Exact amounts: String, Integer or BigDecimal in, two-decimal JSON numbers out, BigDecimal back. A Float amount warns.
- Orders: create (with an optional idempotency key), fetch and terminate.
- Payments: list, fetch, and capture or void a pre-authorised payment.
- UPI on the order session: intent, QR and collect, without sending the client secret.
- Refunds: create with your own `refund_id`, fetch and list.
- Payment links: create, fetch, cancel, and list the orders a link created (needed to refund a link payment).
- `docs/api.md`: every method with its Cashfree endpoint and reference link.
- No telemetry: the gem sends nothing except the Cashfree calls you make.
- Webhook verification with `CashfreePg::Webhook.construct_event`: raw body, constant-time signature check, optional timestamp window, and `SignatureVerificationError` for anything that cannot be trusted, including a missing secret.
- Ruby 3.3 or newer. Faraday 2 is the only runtime dependency.
