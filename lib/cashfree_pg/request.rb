# frozen_string_literal: true

require "json"
require "securerandom"

module CashfreePg
  # One HTTPS call. No retries and no logging.
  #
  # @api private
  class Request
    STATUS_ERRORS = {
      400 => InvalidRequestError,
      401 => AuthenticationError,
      403 => PermissionError,
      404 => NotFoundError,
      409 => ConflictError,
      422 => ValidationError,
      429 => RateLimitError
    }.freeze

    # @param client [Client]
    # @param connection [Faraday::Connection]
    def initialize(client, connection)
      @client = client
      @connection = connection
    end

    # @param method [Symbol] `:get`, `:post` or `:patch`
    # @param path [String]
    # @param body [Hash, nil]
    # @param skip_auth [Boolean]
    # @param idempotency_key [String, nil]
    # @return [Response]
    def perform(method, path, body: nil, skip_auth: false, idempotency_key: nil)
      validate_path!(path)
      @method = method
      @request_id = SecureRandom.uuid
      handle(dispatch(request_path(path), body, request_headers(skip_auth, idempotency_key)))
    rescue Faraday::TimeoutError, Timeout::Error
      raise timeout_error
    rescue Faraday::ConnectionFailed, Faraday::SSLError, Errno::ECONNREFUSED, SocketError
      raise ConnectionError.new("connection failed request_id=#{@request_id}", request_id: @request_id)
    end

    private

    def dispatch(path, body, headers)
      @connection.public_send(@method, path) do |req|
        req.headers.update(headers)
        req.body = JSON.generate(Money.normalize(body)) if body
      end
    end

    def request_headers(skip_auth, idempotency_key)
      headers = {
        "User-Agent" => "cashfree_pg/#{VERSION} ruby/#{RUBY_VERSION}",
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "x-api-version" => @client.api_version,
        "x-request-id" => @request_id
      }
      headers["x-idempotency-key"] = idempotency_key if idempotency_key
      return headers if skip_auth

      headers.merge("x-client-id" => @client.client_id, "x-client-secret" => @client.client_secret)
    end

    def handle(response)
      id = response.headers["x-request-id"]
      id = @request_id if id.nil? || id.empty?
      return success(response, id) if response.success?

      raise_api_error(response, id)
    end

    def success(response, request_id)
      data = parse_json(response.body)
      if data.nil?
        raise APIError.new("invalid JSON response status=#{response.status} request_id=#{request_id}",
                           status: response.status, request_id: request_id, raw_body: response.body.to_s)
      end

      Response.new(data, status: response.status, request_id: request_id)
    end

    def raise_api_error(response, request_id)
      payload = parse_json(response.body)
      payload = {} unless payload.is_a?(Hash)
      klass = STATUS_ERRORS.fetch(response.status, APIError)
      raise klass.new(
        error_message(response.status, payload, request_id),
        status: response.status,
        code: payload["code"]&.to_s,
        type: payload["type"]&.to_s,
        request_id: request_id,
        raw_body: response.body.to_s
      )
    end

    def error_message(status, payload, request_id)
      parts = ["status=#{status}"]
      parts << "code=#{payload["code"]}" if payload["code"]
      parts << "type=#{payload["type"]}" if payload["type"]
      detail = payload["message"].to_s.gsub(@client.client_secret, "[FILTERED]")
      parts << detail unless detail.empty?
      parts << "request_id=#{request_id}"
      parts.join(" ")
    end

    # An empty body is `{}`. Invalid JSON is nil.
    def parse_json(raw)
      text = raw.to_s
      return {} if text.strip.empty?

      JSON.parse(text, decimal_class: BigDecimal)
    rescue JSON::ParserError
      nil
    end

    def timeout_error
      message = "request timed out request_id=#{@request_id}"
      message = "#{message}; outcome is unknown; fetch before retrying" unless @method == :get
      TimeoutError.new(message, request_id: @request_id)
    end

    # A leading slash would make Faraday drop the /pg prefix on the base URL.
    def request_path(path)
      path.delete_prefix("/")
    end

    def validate_path!(path)
      return if path.is_a?(String) && path.start_with?("/") && !path.start_with?("//")

      raise ArgumentError, "path must be a relative path starting with /"
    end
  end
end
