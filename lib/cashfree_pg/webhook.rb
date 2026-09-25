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
    class Event
      # @return [String, nil]
      attr_reader :type

      # @return [String, nil] Cashfree `event_time`
      attr_reader :time

      # @return [Hash, nil]
      attr_reader :data

      # @return [String, nil] `x-webhook-version`
      attr_reader :version

      # @param type [String, nil]
      # @param time [String, nil]
      # @param data [Hash, nil]
      # @param version [String, nil]
      def initialize(type:, time:, data:, version:)
        @type = type
        @time = time
        @data = data
        @version = version
      end
    end

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

    # @param raw_body [String]
    # @param headers [Hash]
    # @param secret [String]
    # @param tolerance [Numeric, nil]
    def initialize(raw_body, headers, secret, tolerance)
      @raw_body = raw_body
      @headers = headers
      @secret = secret
      @tolerance = tolerance
    end

    # @return [Event]
    def construct
      check_body!
      signature = header("x-webhook-signature")
      timestamp = header("x-webhook-timestamp")
      check_present!(signature, "signature")
      check_present!(timestamp, "timestamp")
      check_signature!(timestamp, signature)
      check_window!(timestamp)
      build_event(parse_body, header("x-webhook-version"))
    end

    private

    def check_body!
      raise SignatureVerificationError, "webhook body must be a string" unless @raw_body.is_a?(String)
      raise SignatureVerificationError, "webhook body is empty" if @raw_body.empty?
    end

    def check_present!(value, name)
      raise SignatureVerificationError, "webhook #{name} is missing" if value.nil?
      raise SignatureVerificationError, "webhook #{name} is empty" if value.to_s.strip.empty?
    end

    def check_signature!(timestamp, signature)
      expected = signature_for(timestamp)
      actual = signature.to_s
      return if same_signature?(expected, actual)

      raise SignatureVerificationError, "webhook signature does not match"
    end

    def same_signature?(expected, actual)
      return false unless actual.bytesize == expected.bytesize

      OpenSSL.fixed_length_secure_compare(expected, actual)
    end

    def signature_for(timestamp)
      digest = OpenSSL::HMAC.digest("SHA256", @secret.to_s, "#{timestamp}#{@raw_body}")
      [digest].pack("m0")
    end

    def check_window!(timestamp)
      return if @tolerance.nil?
      return if within_window?(timestamp)

      raise SignatureVerificationError, "webhook timestamp is outside the allowed window"
    end

    def within_window?(timestamp)
      seconds = Integer(timestamp, 10) / 1000.0
      (Time.now.to_f - seconds).abs <= @tolerance
    rescue ArgumentError
      false
    end

    def header(name)
      raise SignatureVerificationError, "webhook headers are missing" unless @headers.respond_to?(:each)

      @headers.each do |key, value|
        return value if header_name(key) == name
      end
      nil
    end

    def header_name(key)
      text = key.to_s.downcase.tr("_", "-")
      text.start_with?("http-") ? text.delete_prefix("http-") : text
    end

    def parse_body
      JSON.parse(@raw_body, decimal_class: BigDecimal)
    rescue JSON::ParserError
      raise SignatureVerificationError, "webhook body is not JSON"
    end

    def build_event(payload, version)
      raise SignatureVerificationError, "webhook body is not JSON" unless payload.is_a?(Hash)

      Event.new(type: payload["type"], time: payload["event_time"], data: payload["data"], version: version)
    end
  end
end
