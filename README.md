# cashfree_pg

[![CI](https://github.com/muballighshahid-dot/cashfree_pg/actions/workflows/ci.yml/badge.svg)](https://github.com/muballighshahid-dot/cashfree_pg/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.txt)

An unofficial Ruby client for the [Cashfree Payments](https://www.cashfree.com) API: orders, payments (including UPI), refunds, payment links and webhook verification.

> This project is not affiliated with, endorsed by, or supported by Cashfree Payments.
>
> v0.1.0 is ready in this repository. It is not on RubyGems until the `v0.1.0` tag is pushed. The public API may change before v1.0.

The gem talks only to Cashfree over HTTPS. It never connects to NPCI or a bank, and it never sends raw card data. It has no telemetry: no analytics, no error reporting service, and no request logging.

Every method, its Cashfree endpoint, and a link to Cashfree's reference are listed in [docs/api.md](docs/api.md).

## Installation

Ruby 3.3 or newer.

```ruby
gem "cashfree_pg", "~> 0.1.0"
```

Then `bundle install`.

## Configure

Use one client per merchant. Credentials stay on that instance.

```ruby
client = CashfreePg::Client.new(
  client_id:     ENV.fetch("CASHFREE_CLIENT_ID"),
  client_secret: ENV.fetch("CASHFREE_CLIENT_SECRET"),
  environment:   :sandbox # or :production
)
```

The default API version is `2025-01-01`. Pass `api_version:` to pin another version. Amounts are decimal rupees (`"10.10"`), sent as JSON numbers. Do not pass a `Float`.

`bin/console` loads `.env` and refuses any environment other than sandbox.

## Orders

```ruby
order = client.orders.create(
  order_id:         "order_123",
  order_amount:     "10.10",
  order_currency:   "INR",
  customer_details: { customer_id: "cust_1", customer_phone: "9999999999" }
)

order.payment_session_id
client.orders.fetch(order.order_id).order_status
client.orders.terminate(order.order_id).order_status # unpaid orders only
```

A duplicate merchant `order_id` raises `CashfreePg::ConflictError`. The gem does not retry. If a create times out, fetch the order before trying again. `create` also accepts `idempotency_key:`, sent as `x-idempotency-key`.

`terminate` can return `TERMINATION_REQUESTED`. Fetch the order to confirm it reached `TERMINATED`; an order with a successful payment is not terminated.

## UPI and other payments

UPI is started on the order session. Intent does not need a VPA. QR returns a QR payload. Collect is the legacy flow and needs a VPA. Sandbox success uses `testsuccess@gocash`.

```ruby
client.payments.upi(order, channel: :intent)
client.payments.upi(order, channel: :qr)
client.payments.upi(order, channel: :collect, upi_id: "testsuccess@gocash")
```

`:intent` is sent as Cashfree's channel `link`. Other Cashfree UPI fields, such as `upi_expiry_minutes`, are passed through as keywords.

Order Pay from your server needs S2S enabled in the Cashfree dashboard. A 403 is `CashfreePg::PermissionError`.

```ruby
payments = client.payments.list(order.order_id)
client.payments.fetch(order.order_id, payments.first.cf_payment_id)

client.payments.authorize(order.order_id, action: :capture, amount: "10.10", idempotency_key: "cap_1")
client.payments.authorize(order.order_id, action: :void, idempotency_key: "void_1")
```

## Refunds

Pass your own `refund_id`. If create times out, fetch that id before creating another refund. A duplicate id is `CashfreePg::ConflictError`.

```ruby
client.refunds.create(order.order_id, refund_amount: "10.10", refund_id: "refund_00912", refund_note: "SUCCESS")
client.refunds.fetch(order.order_id, "refund_00912")
client.refunds.list(order.order_id).to_h
```

`refund_note` values `SUCCESS`, `FAILED`, `PENDING`, and `ACTIVE` simulate status in sandbox. The order must already be paid. `list` returns Cashfree's array unchanged.

## Payment links

SMS is sent only in production. Sandbox can send email when `send_email` is true.

```ruby
link = client.payment_links.create(
  link_id: "link_123",
  link_amount: "10.10",
  link_currency: "INR",
  link_purpose: "Test payment",
  customer_details: { customer_phone: "9999999999", customer_email: "test@example.com" },
  link_notify: { send_sms: false, send_email: false }
)

client.payment_links.fetch(link.link_id)
client.payment_links.cancel(link.link_id)

paid = client.payment_links.orders(link.link_id) # paid orders; pass status: "ALL" for every order
client.refunds.create(paid.first.order_id, refund_amount: "10.10", refund_id: "refund_link_1")
```

`link.link_url` is the URL to give the customer. Only an `ACTIVE` link can be cancelled. Cashfree creates the order when a link is paid, so use `orders` to find the `order_id` for a refund.

## Errors

| Exception | When |
| --- | --- |
| `InvalidRequestError` | HTTP 400 |
| `AuthenticationError` | HTTP 401 |
| `PermissionError` | HTTP 403 |
| `NotFoundError` | HTTP 404 |
| `ConflictError` | HTTP 409, including a duplicate order, refund, or link id |
| `ValidationError` | HTTP 422 |
| `RateLimitError` | HTTP 429 |
| `APIError` | HTTP 5xx and any other unexpected status, including redirects |
| `ConnectionError` | DNS, connection refused, or TLS failure |
| `TimeoutError` | The call timed out and was not retried |
| `SignatureVerificationError` | The webhook could not be trusted |

`inspect` and error messages hide the client secret. There is no request logging and no automatic retry.

## Webhooks

Pass the raw body. Parsing it first changes amounts and the signature will not match.

```ruby
event = CashfreePg::Webhook.construct_event(
  raw_body: request.raw_post,
  headers:  request.headers,
  secret:   ENV.fetch("CASHFREE_CLIENT_SECRET")
)

event.type
event.time
event.data
event.version
```

A failed check raises `SignatureVerificationError` and returns no event. A blank or missing `secret` also fails. The timestamp window is off unless you pass `tolerance:` in seconds. Answer `200` quickly and deduplicate in your app. Details and the optional IP allow-list are in [docs/webhooks.md](docs/webhooks.md).

## Example

`examples/checkout.rb` verifies a sample webhook offline. With sandbox credentials it also creates an order and starts a UPI intent:

```bash
bundle exec ruby examples/checkout.rb
```

## Development

```bash
bin/setup                 # install dependencies
cp .env.example .env      # optional: sandbox credentials for bin/console
bundle exec rake          # specs, RuboCop, RBS, and gem contents check
bin/console               # sandbox only
```

`spec/integration` calls the real sandbox. It skips unless `CASHFREE_CLIENT_ID` and `CASHFREE_CLIENT_SECRET` are set, and the refund test also needs `CASHFREE_PAID_ORDER_ID`:

```bash
set -a; source .env; set +a
bundle exec rspec spec/integration
```

Never commit `.env` or real credentials.

## Security

Please do not report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. Everyone interacting with the project is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## License

Available as open source under the terms of the [MIT License](LICENSE.txt).
