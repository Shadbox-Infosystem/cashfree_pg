# frozen_string_literal: true

module CashfreePg
  # Base error. The message never includes the raw body or the client secret.
  class Error < StandardError
    # @return [Integer, nil] HTTP status, when the server responded
    attr_reader :status

    # @return [String, nil] Cashfree error code
    attr_reader :code

    # @return [String, nil] Cashfree error type
    attr_reader :type

    # @return [String, nil] x-request-id for this call
    attr_reader :request_id

    # @return [String, nil] response body, for callers who need it
    attr_reader :raw_body

    # @param message [String, nil]
    # @param status [Integer, nil]
    # @param code [String, nil]
    # @param type [String, nil]
    # @param request_id [String, nil]
    # @param raw_body [String, nil]
    def initialize(message = nil, status: nil, code: nil, type: nil, request_id: nil, raw_body: nil)
      @status = status
      @code = code
      @type = type
      @request_id = request_id
      @raw_body = raw_body
      super(message)
    end

    # @return [String]
    def inspect
      "#<#{self.class.name} status=#{status.inspect} code=#{code.inspect} " \
        "type=#{type.inspect} request_id=#{request_id.inspect} message=#{message.inspect} raw_body=[FILTERED]>"
    end
  end

  # HTTP 400.
  class InvalidRequestError < Error; end

  # HTTP 401.
  class AuthenticationError < Error; end

  # HTTP 403. Product not enabled, or the caller is not allowed.
  class PermissionError < Error; end

  # HTTP 404.
  class NotFoundError < Error; end

  # HTTP 409. A duplicate order, refund, or link id.
  class ConflictError < Error; end

  # HTTP 422.
  class ValidationError < Error; end

  # HTTP 429.
  class RateLimitError < Error; end

  # HTTP 5xx and any other unexpected status.
  class APIError < Error; end

  # No response was received (DNS, connection refused, TLS).
  class ConnectionError < Error; end

  # The call timed out and was not retried. For POST, fetch the resource before trying again.
  class TimeoutError < Error; end

  # The webhook signature, headers, or body could not be trusted.
  class SignatureVerificationError < Error; end
end
