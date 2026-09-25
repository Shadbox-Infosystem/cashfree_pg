# frozen_string_literal: true

require "uri"

module CashfreePg
  # Create and fetch Cashfree orders.
  class Orders
    # @param client [Client]
    def initialize(client)
      @client = client
    end

    # @param attrs [Hash] Cashfree create-order fields. `order_amount` is sent as a two-decimal number.
    # @return [Response]
    # @example
    #   client.orders.create(
    #     order_amount: "10.10",
    #     order_currency: "INR",
    #     customer_details: { customer_id: "cust_1", customer_phone: "9999999999" }
    #   )
    def create(attrs)
      @client.post("/orders", attrs)
    end

    # @param order_id [String] merchant order id
    # @return [Response]
    # @example
    #   client.orders.fetch("order_123")
    def fetch(order_id)
      @client.get("/orders/#{segment(order_id)}")
    end

    private

    def segment(id)
      text = id.to_s.strip
      raise ArgumentError, "order_id is required" if text.empty?
      raise ArgumentError, "order_id must not contain a slash" if text.include?("/")

      URI.encode_uri_component(text)
    end
  end
end
