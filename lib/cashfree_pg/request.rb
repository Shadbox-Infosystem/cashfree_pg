# frozen_string_literal: true

require "json"
require "securerandom"

module CashfreePg
  # One HTTPS call. No retries and no logging.
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

    # @param method [Symbol] `:get` or `:post`
    # @param path [String]
    # @param body [Hash, nil]
    # @param params [Hash, nil]
    # @param skip_auth [Boolean]
    # @param idempotency_key [String, nil]
    # @return [Response]
    def perform(method, path, body: nil, params: nil, skip_auth: false, idempotency_key: nil)
      validate_path!(path)
      remember(method, path, body:, params:, skip_auth:, idempotency_key:)
      handle(dispatch)
    rescue Faraday::TimeoutError, Timeout::Error
      raise timeout_error
    rescue Faraday::ConnectionFailed, Faraday::SSLError, Errno::ECONNREFUSED, SocketError
      raise ConnectionError.new("connection failed request_id=#{@request_id}", request_id: @request_id)
    end

    private

    def dispatch
      @connection.public_send(@method, @path) do |req|
        write_headers(req)
        req.params.update(stringify_keys(@params)) if @params
        req.body = JSON.generate(Money.normalize(@body)) if @body
      end
    end

    def remember(method, path, body:, params:, skip_auth:, idempotency_key:)
      @method = method
      @path = request_path(path)
      @body = body
      @params = params
      @skip_auth = skip_auth
      @idempotency_key = idempotency_key
      @request_id = SecureRandom.uuid
    end

    def write_headers(req)
      req.headers.update(request_headers)
    end

    def request_headers
      headers = {
        "User-Agent" => "cashfree_pg/#{VERSION} ruby/#{RUBY_VERSION}",
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "x-api-version" => @client.api_version,
        "x-request-id" => @request_id
      }
      headers["x-idempotency-key"] = @idempotency_key if @idempotency_key
      return headers if @skip_auth

      headers.merge("x-client-id" => @client.client_id, "x-client-secret" => @client.client_secret)
    end

    def handle(response)
      id = response.headers["x-request-id"]
      id = @request_id if id.nil? || id.empty?
      return success(response, id) if response.success?

      raise_api_error(response, id)
    end

    def success(response, request_id)
      Response.new(parse_success(response, request_id), status: response.status, request_id: request_id)
    end

    def raise_api_error(response, request_id)
      payload = parse_error_body(response.body)
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
      detail = filter_secret(payload["message"]&.to_s)
      parts << detail if detail && !detail.empty?
      parts << "request_id=#{request_id}"
      parts.join(" ")
    end

    def filter_secret(text)
      return if text.nil? || text.empty?

      text.gsub(@client.client_secret, "[FILTERED]")
    end

    def parse_success(response, request_id)
      text = response.body.to_s
      return {} if text.strip.empty?

      JSON.parse(text, decimal_class: BigDecimal)
    rescue JSON::ParserError
      raise APIError.new(
        "invalid JSON response status=#{response.status} request_id=#{request_id}",
        status: response.status,
        request_id: request_id,
        raw_body: text
      )
    end

    def parse_error_body(raw)
      text = raw.to_s
      return {} if text.strip.empty?

      JSON.parse(text, decimal_class: BigDecimal)
    rescue JSON::ParserError
      {}
    end

    def timeout_error
      message = "request timed out request_id=#{@request_id}"
      message = "#{message}; outcome is unknown; fetch before retrying" if @method == :post
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

    def stringify_keys(params)
      params.transform_keys(&:to_s)
    end
  end
end
