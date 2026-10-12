# frozen_string_literal: true

module CashfreePg
  # Collect a payment with a Cashfree link.
  #
  # SMS notifications are sent only in production. Sandbox sends email when
  # `link_notify.send_email` is true, and does not send SMS.
  class PaymentLinks < Resource
    # @param idempotency_key [String, nil]
    # @param attrs [Hash] keyword fields; requires `link_amount`, `link_currency`, `link_purpose` and `customer_details`
    # @return [Response]
    # @example
    #   client.payment_links.create(
    #     link_id: "link_123",
    #     link_amount: "10.10",
    #     link_currency: "INR",
    #     link_purpose: "Test payment",
    #     customer_details: { customer_phone: "9999999999" }
    #   )
    def create(idempotency_key: nil, **attrs)
      @client.post("/links", attrs, idempotency_key: idempotency_key)
    end

    # @param link_id [String] merchant link id
    # @return [Response]
    # @example
    #   client.payment_links.fetch("link_123")
    def fetch(link_id)
      @client.get("/links/#{segment(link_id, "link_id")}")
    end

    # Only an ACTIVE link can be cancelled.
    #
    # @param link_id [String]
    # @return [Response]
    # @example
    #   client.payment_links.cancel("link_123")
    def cancel(link_id)
      @client.post("/links/#{segment(link_id, "link_id")}/cancel")
    end

    # Orders Cashfree created for a link. Use an order's `order_id` to refund a link payment.
    #
    # @param link_id [String]
    # @param status [String, nil] `"PAID"` or `"ALL"`; Cashfree returns paid orders when nil
    # @return [Array<Response>]
    # @example
    #   order_id = client.payment_links.orders("link_123").first.order_id
    def orders(link_id, status: nil)
      path = "/links/#{segment(link_id, "link_id")}/orders"
      path += "?#{URI.encode_www_form(status: status)}" if status
      list_of(@client.get(path), "link orders")
    end
  end
end
