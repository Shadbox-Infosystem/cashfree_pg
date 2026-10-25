# frozen_string_literal: true

require "json"
require "openssl"

module CashfreePg
  # Verifies a Cashfree webhook, then parses it.
  #
  # The signature is Base64(HMAC-SHA256(timestamp + raw body, client secret)).
  # Pass the raw body string. A parsed Hash will not match.
  # `tolerance` is a timestamp window in seconds. It is off unless you set it,
  # because Cashfree retries reuse the original timestamp.
  class Webhook
    # A verified event. Unknown `type` values are returned as sent.
    #
    # @!attribute [r] type
    #   @return [String, nil]
    # @!attribute [r] time
    #   @return [String, nil] Cashfree `event_time`
    # @!attribute [r] data
    #   @return [Hash, nil]
    # @!attribute [r] version
    #   @return [String, nil] `x-webhook-version`
    Event = Data.define(:type, :time, :data, :version)

    # @param raw_body [String] exact request body, not a parsed Hash
    # @param headers [Hash] plain Hash, Rack env, or Rails headers
    # @param secret [String] Cashfree client secret
    # @param tolerance [Numeric, nil] seconds; nil skips the timestamp check
    # @return [Event]
    # @raise [SignatureVerificationError]
    # @example
    #   CashfreePg::Webhook.construct_event(
    #     raw_body: request.raw_post,
    #     headers: request.headers,
    #     secret: ENV.fetch("CASHFREE_CLIENT_SECRET")
    #   )
    def self.construct_event(raw_body:, headers:, secret:, tolerance: nil)
      new(raw_body, headers, secret, tolerance).construct
    end
    private_class_method :new

    # @api private
    def initialize(raw_body, headers, secret, tolerance)
      @raw_body = raw_body
      @headers = headers
      @secret = secret
      @tolerance = tolerance
    end

    # @api private
    def construct
      check_input!
      signature = present_header("x-webhook-signature")
      timestamp = present_header("x-webhook-timestamp")
      raise SignatureVerificationError, "webhook signature does not match" unless valid?(timestamp, signature)

      check_window!(timestamp)
      build_event(header("x-webhook-version"))
    end

    private

    # A blank secret would let anyone sign with an empty key.
    def check_input!
      raise SignatureVerificationError, "webhook secret is missing" if @secret.to_s.strip.empty?
      raise SignatureVerificationError, "webhook body must be a string" unless @raw_body.is_a?(String)
      raise SignatureVerificationError, "webhook body is empty" if @raw_body.empty?
      raise SignatureVerificationError, "webhook headers are missing" unless @headers.respond_to?(:each)
    end

    def valid?(timestamp, signature)
      digest = OpenSSL::HMAC.digest("SHA256", @secret.to_s, "#{timestamp}#{@raw_body}")
      expected = [digest].pack("m0")
      signature.bytesize == expected.bytesize && OpenSSL.fixed_length_secure_compare(expected, signature)
    end

    def check_window!(timestamp)
      return if @tolerance.nil? || within_window?(timestamp)

      raise SignatureVerificationError, "webhook timestamp is outside the allowed window"
    end

    def within_window?(timestamp)
      (Time.now.to_f - (Integer(timestamp, 10) / 1000.0)).abs <= @tolerance
    rescue ArgumentError
      false
    end

    def present_header(name)
      value = header(name).to_s
      raise SignatureVerificationError, "webhook #{name.delete_prefix("x-webhook-")} is missing" if value.strip.empty?

      value
    end

    def header(name)
      @headers.each do |key, value|
        return value if header_name(key) == name
      end
      nil
    end

    def header_name(key)
      key.to_s.downcase.tr("_", "-").delete_prefix("http-")
    end

    def build_event(version)
      payload = JSON.parse(@raw_body, decimal_class: BigDecimal)
      raise SignatureVerificationError, "webhook body is not JSON" unless payload.is_a?(Hash)

      Event.new(type: payload["type"], time: payload["event_time"], data: payload["data"], version: version)
    rescue JSON::ParserError
      raise SignatureVerificationError, "webhook body is not JSON"
    end
  end
end
