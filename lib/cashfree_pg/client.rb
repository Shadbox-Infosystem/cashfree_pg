# frozen_string_literal: true

require "faraday"
require_relative "request"

module CashfreePg
  # One merchant's credentials and the calls made with them.
  #
  # Resource accessors (`orders`, `payments`, `refunds`, `payment_links`) are added in later phases.
  #
  # @example
  #   client = CashfreePg::Client.new(
  #     client_id: ENV.fetch("CASHFREE_CLIENT_ID"),
  #     client_secret: ENV.fetch("CASHFREE_CLIENT_SECRET"),
  #     environment: :sandbox
  #   )
  class Client
    SANDBOX_URL = "https://sandbox.cashfree.com/pg"
    PRODUCTION_URL = "https://api.cashfree.com/pg"
    DEFAULT_API_VERSION = "2025-01-01"

    # @return [String]
    attr_reader :client_id

    # @return [String]
    attr_reader :client_secret

    # @return [Symbol]
    attr_reader :environment

    # @return [String]
    attr_reader :api_version

    # @return [Numeric]
    attr_reader :open_timeout

    # @return [Numeric]
    attr_reader :read_timeout

    # @return [String]
    attr_reader :base_url

    # @param client_id [String]
    # @param client_secret [String]
    # @param environment [Symbol] `:sandbox` or `:production`
    # @param api_version [String]
    # @param open_timeout [Numeric]
    # @param read_timeout [Numeric]
    # @param base_url [String, nil] test-only override; must be https
    # @param allow_custom_base_url [Boolean]
    def initialize(client_id:, client_secret:, environment: :sandbox, api_version: DEFAULT_API_VERSION,
                   open_timeout: 30, read_timeout: 60, base_url: nil, allow_custom_base_url: false)
      @client_id = required_string(client_id, "client_id")
      @client_secret = required_string(client_secret, "client_secret")
      @environment = environment
      @api_version = required_string(api_version, "api_version")
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @base_url = resolve_base_url(base_url, allow_custom_base_url)
      @connection = build_connection
    end

    # @param path [String] absolute path on the Cashfree host, such as `/orders`
    # @param params [Hash, nil] query string
    # @param skip_auth [Boolean] omit client id and secret; `x-api-version` is still sent
    # @return [Response]
    # @example
    #   client.get("/orders/order_123")
    def get(path, params = nil, skip_auth: false)
      call(:get, path, params: params, skip_auth: skip_auth)
    end

    # @param path [String]
    # @param body [Hash, nil]
    # @param skip_auth [Boolean]
    # @param idempotency_key [String, nil] sent as `x-idempotency-key`; the gem does not retry
    # @return [Response]
    # @example
    #   client.post("/orders", { order_amount: "10.10", order_currency: "INR" })
    def post(path, body = nil, skip_auth: false, idempotency_key: nil)
      call(:post, path, body: body, skip_auth: skip_auth, idempotency_key: idempotency_key)
    end

    # @return [String] client secret is always `[FILTERED]`
    def inspect
      "#<CashfreePg::Client environment=#{environment.inspect} api_version=#{api_version.inspect} " \
        "client_id=#{client_id.inspect} client_secret=[FILTERED]>"
    end
    alias to_s inspect

    # @param printer [PP]
    # @return [void]
    def pretty_print(printer)
      printer.text(inspect)
    end

    private

    def call(method, path, **)
      Request.new(self, @connection).perform(method, path, **)
    end

    def required_string(value, name)
      string = value.to_s
      raise ArgumentError, "#{name} is required" if string.strip.empty?

      string
    end

    def resolve_base_url(custom, allowed)
      return environment_url if custom.nil?
      raise ArgumentError, "base_url is only allowed when allow_custom_base_url: true" unless allowed
      raise ArgumentError, "base_url must use https" unless custom.start_with?("https://")

      custom.chomp("/")
    end

    def environment_url
      case environment
      when :sandbox then SANDBOX_URL
      when :production then PRODUCTION_URL
      else
        raise ArgumentError, "environment must be :sandbox or :production"
      end
    end

    def build_connection
      Faraday.new(url: base_url) do |faraday|
        faraday.options.open_timeout = open_timeout
        faraday.options.timeout = read_timeout
        faraday.ssl.verify = true
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
