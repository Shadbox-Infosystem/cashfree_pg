# frozen_string_literal: true

module CashfreePg
  # Refunds for a paid order.
  #
  # Pass your own `refund_id`. If a create times out, fetch that id before sending
  # another refund. Cashfree rejects a duplicate `refund_id` with 409, which is a {ConflictError}.
  class Refunds < Resource
    # @param order_id [String]
    # @param idempotency_key [String, nil]
    # @param attrs [Hash] keyword fields; requires `refund_amount` and `refund_id`
    # @return [Response]
    # @example
    #   client.refunds.create("order_123", refund_amount: "10.10", refund_id: "refund_00912")
    def create(order_id, idempotency_key: nil, **attrs)
      @client.post("#{order_path(order_id)}/refunds", attrs, idempotency_key: idempotency_key)
    end

    # @param order_id [String]
    # @param refund_id [String] the merchant refund id
    # @return [Response]
    # @example
    #   client.refunds.fetch("order_123", "refund_00912")
    def fetch(order_id, refund_id)
      @client.get("#{order_path(order_id)}/refunds/#{segment(refund_id, "refund_id")}")
    end

    # Cashfree returns a JSON array. It is not wrapped item by item.
    #
    # @param order_id [String]
    # @return [Response]
    # @example
    #   client.refunds.list("order_123").to_h
    def list(order_id)
      @client.get("#{order_path(order_id)}/refunds")
    end
  end
end
