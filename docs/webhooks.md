# Webhooks

Verify the signature before you trust a Cashfree webhook. The gem checks `Base64(HMAC-SHA256(timestamp + raw body, client secret))` and raises `CashfreePg::SignatureVerificationError` when the body, headers, or signature cannot be trusted. It does not return an event in that case.

Legacy form-encoded webhooks are not supported. Cashfree's current payloads are JSON.

## Verify

Use the raw request body. Parsing it first changes numbers such as `10.10` and the signature will not match.

```ruby
event = CashfreePg::Webhook.construct_event(
  raw_body: request.raw_post,
  headers:  request.headers,
  secret:   ENV.fetch("CASHFREE_CLIENT_SECRET")
)

event.type     # "PAYMENT_SUCCESS_WEBHOOK", including types this gem does not know
event.time     # event_time from the payload
event.data     # the data object
event.version  # x-webhook-version
```

`headers` may be a plain Hash, a Rack env (`HTTP_X_WEBHOOK_SIGNATURE`), or Rails request headers.

In Rails, `request.raw_post` is the raw body. Read it before anything else parses the request.

## Respond and deduplicate

Answer `200` as soon as the signature is valid, then do the work. Cashfree retries when the endpoint is slow or returns an error, and a retry sends the same timestamp.

Store a key you already have, such as the payment id inside `event.data` or the `x-idempotency-key` header, and ignore a repeat. The gem does not store events.

## Timestamp window

`tolerance` is off by default, in seconds. Turn it on only if you accept that a legitimate retry older than the window will fail:

```ruby
CashfreePg::Webhook.construct_event(
  raw_body: request.raw_post,
  headers: request.headers,
  secret: ENV.fetch("CASHFREE_CLIENT_SECRET"),
  tolerance: 300
)
```

The timestamp is milliseconds (`x-webhook-timestamp`).

## IP allow-list

An allow-list is optional and does not replace the signature check. Cashfree publishes these source addresses, and they change, so confirm the current list in [Cashfree's webhook security checklist](https://www.cashfree.com/docs/payments/online/webhooks/security-checklist) before you lock a firewall.

| Environment | Addresses |
| --- | --- |
| Sandbox | `52.66.25.127`, `15.206.45.168` |
| Production | `52.66.101.190`, `3.109.102.144`, `18.60.134.245`, `18.60.183.142` |

Allow HTTPS port 443 only.
