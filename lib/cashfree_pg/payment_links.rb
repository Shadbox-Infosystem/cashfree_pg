# frozen_string_literal: true

require "uri"

module CashfreePg
  # Collect a payment with a Cashfree link.
  #
  # SMS notifications are sent only in production. Sandbox sends email when
  # `link_notify.send_email` is true, and does not send SMS.
  class PaymentLinks
    # @param client [Client]
    def initialize(client)
      @client = client
    end

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
      @client.get("/links/#{segment(link_id)}")
    end

    # Only an ACTIVE link can be cancelled.
    #
    # @param link_id [String]
    # @return [Response]
    # @example
    #   client.payment_links.cancel("link_123")
    def cancel(link_id)
      @client.post("/links/#{segment(link_id)}/cancel")
    end

    private

    def segment(id)
      text = id.to_s.strip
      raise ArgumentError, "link_id is required" if text.empty?
      raise ArgumentError, "link_id must not contain a slash" if text.include?("/")

      URI.encode_uri_component(text)
    end
  end
end
