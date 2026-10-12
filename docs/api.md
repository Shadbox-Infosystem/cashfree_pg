# API reference

Every gem method, the Cashfree endpoint it calls, and Cashfree's page for that endpoint. Request fields and response bodies are Cashfree's; follow the link for the full list.

Paths are relative to `https://sandbox.cashfree.com/pg` or `https://api.cashfree.com/pg`. Every call sends `x-api-version` (default `2025-01-01`) and an `x-request-id`.

| Gem method | Endpoint | Cashfree reference |
| --- | --- | --- |
| `client.orders.create(**attrs, idempotency_key: nil)` | `POST /orders` | [Create Order](https://www.cashfree.com/docs/api-reference/payments/latest/orders/create) |
| `client.orders.fetch(order_id)` | `GET /orders/{order_id}` | [Get Order](https://www.cashfree.com/docs/api-reference/payments/latest/orders/get) |
| `client.orders.terminate(order_id)` | `PATCH /orders/{order_id}` | [Terminate Order](https://www.cashfree.com/docs/api-reference/payments/latest/orders/terminate) |
| `client.payments.list(order_id)` | `GET /orders/{order_id}/payments` | [Get Payments for an Order](https://www.cashfree.com/docs/api-reference/payments/latest/payments/get-payments-for-an-order) |
| `client.payments.fetch(order_id, cf_payment_id)` | `GET /orders/{order_id}/payments/{cf_payment_id}` | [Get Payment by ID](https://www.cashfree.com/docs/api-reference/payments/latest/payments/get-payment-by-id) |
| `client.payments.upi(order, channel:, upi_id: nil, **options)` | `POST /orders/sessions` (no client secret) | [Order Pay](https://www.cashfree.com/docs/api-reference/payments/latest/payments/pay) |
| `client.payments.authorize(order_id, action:, amount: nil, idempotency_key: nil)` | `POST /orders/{order_id}/authorization` | [Preauthorisation](https://www.cashfree.com/docs/api-reference/payments/latest/payments/authorize) |
| `client.refunds.create(order_id, **attrs, idempotency_key: nil)` | `POST /orders/{order_id}/refunds` | [Create Refund](https://www.cashfree.com/docs/api-reference/payments/latest/refunds/create) |
| `client.refunds.fetch(order_id, refund_id)` | `GET /orders/{order_id}/refunds/{refund_id}` | [Get Refund](https://www.cashfree.com/docs/api-reference/payments/latest/refunds/get) |
| `client.refunds.list(order_id)` | `GET /orders/{order_id}/refunds` | [Get All Refunds for an Order](https://www.cashfree.com/docs/api-reference/payments/latest/refunds/get-all-refunds-for-an-order) |
| `client.payment_links.create(**attrs, idempotency_key: nil)` | `POST /links` | [Create Payment Link](https://www.cashfree.com/docs/api-reference/payments/latest/payment-links/create) |
| `client.payment_links.fetch(link_id)` | `GET /links/{link_id}` | [Fetch Payment Link Details](https://www.cashfree.com/docs/api-reference/payments/latest/payment-links/get) |
| `client.payment_links.cancel(link_id)` | `POST /links/{link_id}/cancel` | [Cancel Payment Link](https://www.cashfree.com/docs/api-reference/payments/latest/payment-links/cancel) |
| `client.payment_links.orders(link_id, status: nil)` | `GET /links/{link_id}/orders` | [Get Orders for a Payment Link](https://www.cashfree.com/docs/api-reference/payments/latest/payment-links/get-orders-for-a-payment-link) |
| `CashfreePg::Webhook.construct_event(raw_body:, headers:, secret:, tolerance: nil)` | none; runs in your app | [Verify Webhook Signatures](https://www.cashfree.com/docs/payments/online/webhooks/signature-verification) |

## Return values

- Single objects are a `CashfreePg::Response`: read fields as methods (`order.order_status`) or with `[]` and `dig`. `status` and `request_id` are on every response.
- `payments.list` and `payment_links.orders` return an Array of `Response`.
- `refunds.list` returns one `Response`; `to_h` is Cashfree's array unchanged.
- Amounts come back as `BigDecimal`.

## Errors

| HTTP status | Exception |
| --- | --- |
| 400 | `CashfreePg::InvalidRequestError` |
| 401 | `CashfreePg::AuthenticationError` |
| 403 | `CashfreePg::PermissionError` |
| 404 | `CashfreePg::NotFoundError` |
| 409 | `CashfreePg::ConflictError` |
| 422 | `CashfreePg::ValidationError` |
| 429 | `CashfreePg::RateLimitError` |
| 5xx and anything else | `CashfreePg::APIError` |
| No response | `CashfreePg::ConnectionError` or `CashfreePg::TimeoutError` |

Every error has `status`, `code`, `type` and `request_id`. Give Cashfree the `request_id` when you ask about a failed call.
