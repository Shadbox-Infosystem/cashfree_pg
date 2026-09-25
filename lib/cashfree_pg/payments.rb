# frozen_string_literal: true

require "uri"

module CashfreePg
  # Payments for an order, including UPI via Cashfree order sessions.
  #
  # The gem talks only to Cashfree. It never connects to NPCI or a bank.
  # Calling Order Pay from a server needs Cashfree's S2S feature enabled.
  # A 403 is a {PermissionError} that says so.
  class Payments
    # Cashfree channel names. `:intent` is UPI intent; Cashfree calls that channel `link`.
    CHANNELS = {
      intent: "link",
      link: "link",
      qr: "qrcode",
      qrcode: "qrcode",
      pod_qr: "podQrCode",
      collect: "collect"
    }.freeze

    # @param client [Client]
    def initialize(client)
      @client = client
    end

    # @param order_id [String]
    # @return [Array<Response>]
    # @example
    #   client.payments.list("order_123")
    def list(order_id)
      response = @client.get("/orders/#{segment(order_id)}/payments")
      items = response.to_h
      unless items.is_a?(Array)
        raise APIError.new("payments list was not an array", status: response.status, request_id: response.request_id)
      end

      items.map { |item| Response.new(item, status: response.status, request_id: response.request_id) }
    end

    # @param order_id [String]
    # @param cf_payment_id [String]
    # @return [Response]
    # @example
    #   client.payments.fetch("order_123", "12376123")
    def fetch(order_id, cf_payment_id)
      @client.get("/orders/#{segment(order_id)}/payments/#{segment(cf_payment_id, "cf_payment_id")}")
    end

    # Start a UPI payment on an order session. No client secret is sent.
    #
    # Channels: `:intent` (opens the UPI app), `:qr` (QR image), `:collect` (legacy; needs `upi_id`).
    # Sandbox collect VPAs include `testsuccess@gocash`.
    #
    # @param order [Response, Hash, String] order response, or the payment_session_id
    # @param channel [Symbol, String]
    # @param upi_id [String, nil] required for `:collect`
    # @param upi_expiry_minutes [Integer, nil] collect only; passed through when set
    # @param upi_redirect_url [Boolean, nil]
    # @return [Response]
    # @example
    #   client.payments.upi(order, channel: :intent)
    #   client.payments.upi(order, channel: :collect, upi_id: "testsuccess@gocash")
    def upi(order, channel:, upi_id: nil, upi_expiry_minutes: nil, upi_redirect_url: nil)
      cashfree_channel = CHANNELS[channel.to_sym]
      raise ArgumentError, "channel must be one of #{CHANNELS.keys.join(", ")}" unless cashfree_channel

      check_vpa!(upi_id) if upi_id
      raise ArgumentError, "collect requires upi_id" if cashfree_channel == "collect" && upi_id.nil?

      pay(session_id(order), upi_body(cashfree_channel, upi_id, upi_expiry_minutes, upi_redirect_url))
    end

    # Capture or void a pre-authorised payment. `CAPTURE` requires an amount.
    #
    # @param order_id [String]
    # @param action [Symbol, String] `:capture` or `:void`
    # @param amount [String, Integer, BigDecimal, nil]
    # @param idempotency_key [String, nil]
    # @return [Response]
    # @example
    #   client.payments.authorize("order_123", action: :capture, amount: "10.10", idempotency_key: "cap_1")
    def authorize(order_id, action:, amount: nil, idempotency_key: nil)
      name = action.to_s.upcase
      raise ArgumentError, "action must be CAPTURE or VOID" unless %w[CAPTURE VOID].include?(name)
      raise ArgumentError, "CAPTURE requires an amount" if name == "CAPTURE" && amount.nil?
      raise ArgumentError, "VOID does not take an amount" if name == "VOID" && !amount.nil?

      body = { action: name }
      body[:amount] = amount unless amount.nil?
      @client.post("/orders/#{segment(order_id)}/authorization", body, idempotency_key: idempotency_key)
    end

    private

    def pay(payment_session_id, upi)
      @client.post(
        "/orders/sessions",
        { payment_session_id: payment_session_id, payment_method: { upi: upi } },
        skip_auth: true
      )
    rescue PermissionError => e
      raise PermissionError.new(
        "#{e.message}. Order Pay from a server needs Cashfree S2S enabled on the account",
        status: e.status, code: e.code, type: e.type,
        request_id: e.request_id, raw_body: e.raw_body
      )
    end

    def upi_body(channel, upi_id, expiry, redirect)
      body = { channel: channel }
      body[:upi_id] = upi_id if upi_id
      body[:upi_expiry_minutes] = expiry if expiry
      body[:upi_redirect_url] = redirect unless redirect.nil?
      body
    end

    def session_id(order)
      return order if order.is_a?(String) && !order.empty?

      id = order["payment_session_id"] || order[:payment_session_id] if order.respond_to?(:[])
      raise ArgumentError, "payment_session_id is required" if id.nil? || id.to_s.empty?

      id
    end

    def check_vpa!(upi_id)
      return if upi_id.to_s.match?(/\A[^@\s]+@[^@\s]+\z/)

      raise ArgumentError, "upi_id must look like name@bank"
    end

    def segment(id, name = "order_id")
      text = id.to_s.strip
      raise ArgumentError, "#{name} is required" if text.empty?
      raise ArgumentError, "#{name} must not contain a slash" if text.include?("/")

      URI.encode_uri_component(text)
    end
  end
end
