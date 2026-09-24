# cashfree_pg

[![CI](https://github.com/muballighshahid-dot/cashfree_pg/actions/workflows/ci.yml/badge.svg)](https://github.com/muballighshahid-dot/cashfree_pg/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.txt)

An unofficial Ruby client for the [Cashfree Payments](https://www.cashfree.com) API: orders, payments, UPI, refunds, payment links and webhook verification.

> **Status:** under active development. Not yet released to RubyGems. The public API may change before v1.0.
>
> This project is not affiliated with, endorsed by, or supported by Cashfree Payments.

## Goals

- Instance-based, thread-safe client with per-client credentials
- Cashfree API version pinning with per-client override
- Exact money handling (`BigDecimal`, never `Float`)
- Safe webhook verification (raw body, constant-time comparison)
- Secrets and personal data never logged or shown in errors
- Faraday as the only runtime dependency; Rails optional

See the [project plan](docs/cashfree_pg_project_plan.md) and [decision log](docs/decisions.md) for details.

## Installation

The gem is not published yet. Installation instructions will be added with the v0.1.0 release.

## Quick start

Coming in v0.1.0. The target usage is:

```ruby
client = CashfreePg::Client.new(
  client_id:     ENV.fetch("CASHFREE_CLIENT_ID"),
  client_secret: ENV.fetch("CASHFREE_CLIENT_SECRET"),
  environment:   :sandbox
)

order = client.orders.create(
  order_amount:     "10.10",
  order_currency:   "INR",
  customer_details: { customer_id: "cust_1", customer_phone: "9999999999" }
)
```

## Requirements

- Ruby 3.3 or newer

## Development

```bash
bin/setup                 # install dependencies
cp .env.example .env      # optional: add SANDBOX credentials for bin/console
bundle exec rake          # specs, RuboCop and gem contents check
bin/console               # interactive prompt
```

Never commit `.env` or real credentials. Use Cashfree sandbox credentials only.

## Security

Please do not report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. Everyone interacting with the project is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## License

Available as open source under the terms of the [MIT License](LICENSE.txt).
