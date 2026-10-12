# frozen_string_literal: true

module CashfreePg
  # Create, fetch and terminate Cashfree orders.
  class Orders < Resource
    # A duplicate merchant `order_id` is a {ConflictError}, so reusing your own
    # `order_id` is the safest way to retry after a timeout.
    #
    # @param idempotency_key [String, nil]
    # @param attrs [Hash] Cashfree create-order fields. `order_amount` is sent as a two-decimal number.
    # @return [Response]
    # @example
    #   client.orders.create(
    #     order_id: "order_123",
    #     order_amount: "10.10",
    #     order_currency: "INR",
    #     customer_details: { customer_id: "cust_1", customer_phone: "9999999999" }
    #   )
    def create(idempotency_key: nil, **attrs)
      @client.post("/orders", attrs, idempotency_key: idempotency_key)
    end

    # @param order_id [String] merchant order id
    # @return [Response]
    # @example
    #   client.orders.fetch("order_123")
    def fetch(order_id)
      @client.get(order_path(order_id))
    end

    # Ask Cashfree to terminate an unpaid order. The returned `order_status` may be
    # `TERMINATION_REQUESTED`; fetch the order to confirm it reached `TERMINATED`.
    #
    # @param order_id [String] merchant order id
    # @return [Response]
    # @example
    #   client.orders.terminate("order_123").order_status
    def terminate(order_id)
      @client.patch(order_path(order_id), { order_status: "TERMINATED" })
    end
  end
end
