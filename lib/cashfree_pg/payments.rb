# frozen_string_literal: true

module CashfreePg
  # Payments for an order, including UPI via Cashfree order sessions.
  #
  # The gem talks only to Cashfree. It never connects to NPCI or a bank.
  # Calling Order Pay from a server needs Cashfree's S2S feature enabled.
  # A 403 is a {PermissionError} that says so.
  class Payments < Resource
    # Cashfree channel names. `:intent` is UPI intent; Cashfree calls that channel `link`.
    CHANNELS = {
      intent: "link",
      link: "link",
      qr: "qrcode",
      qrcode: "qrcode",
      pod_qr: "podQrCode",
      collect: "collect"
    }.freeze

    # @param order_id [String]
    # @return [Array<Response>]
    # @example
    #   client.payments.list("order_123")
    def list(order_id)
      list_of(@client.get("#{order_path(order_id)}/payments"), "payments")
    end

    # @param order_id [String]
    # @param cf_payment_id [String]
    # @return [Response]
    # @example
    #   client.payments.fetch("order_123", "12376123")
    def fetch(order_id, cf_payment_id)
      @client.get("#{order_path(order_id)}/payments/#{segment(cf_payment_id, "cf_payment_id")}")
    end

    # Start a UPI payment on an order session. No client secret is sent.
    #
    # Channels: `:intent` (opens the UPI app), `:qr` (QR image), `:collect` (legacy; needs `upi_id`).
    # Sandbox collect VPAs include `testsuccess@gocash`.
    #
    # @param order [Response, Hash, String] order response, or the payment_session_id
    # @param channel [Symbol, String]
    # @param upi_id [String, nil] required for `:collect`
    # @param options [Hash] other Cashfree UPI fields, such as `upi_expiry_minutes`
    # @return [Response]
    # @example
    #   client.payments.upi(order, channel: :intent)
    #   client.payments.upi(order, channel: :collect, upi_id: "testsuccess@gocash")
    def upi(order, channel:, upi_id: nil, **options)
      cashfree_channel = CHANNELS[channel.to_sym]
      raise ArgumentError, "channel must be one of #{CHANNELS.keys.join(", ")}" unless cashfree_channel
      raise ArgumentError, "collect requires upi_id" if cashfree_channel == "collect" && upi_id.nil?

      check_vpa!(upi_id) if upi_id
      upi = { channel: cashfree_channel, upi_id: upi_id }.compact.merge(options)
      pay(session_id(order), upi)
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

      body = { action: name, amount: amount }.compact
      @client.post("#{order_path(order_id)}/authorization", body, idempotency_key: idempotency_key)
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
  end
end
