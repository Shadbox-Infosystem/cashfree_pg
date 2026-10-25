# frozen_string_literal: true

module CashfreePg
  # Hash-like Cashfree response. Field names stay as Cashfree sends them.
  #
  # Use {#[]} or {#dig} for keys that collide with Ruby methods (`hash`, `class`, `method`).
  class Response
    # @return [Integer]
    attr_reader :status

    # @return [String]
    attr_reader :request_id

    # @param data [Hash, Array]
    # @param status [Integer]
    # @param request_id [String]
    def initialize(data, status:, request_id:)
      @data = data
      @status = status
      @request_id = request_id
    end

    # @param key [String, Symbol]
    # @return [Object, nil]
    def [](key)
      body[key.to_s]
    end

    # @param keys [Array<String, Symbol>]
    # @return [Object, nil]
    def dig(*keys)
      body.dig(*keys.map(&:to_s))
    end

    # @return [Hash, Array]
    def to_h
      @data.is_a?(Hash) ? @data.dup : @data
    end

    # @param name [Symbol]
    # @return [Object]
    def method_missing(name, *args)
      key = name.to_s
      if args.empty? && !name.end_with?("=") && body.key?(key) && !self.class.method_defined?(name)
        body[key]
      else
        super
      end
    end

    # @param name [Symbol]
    # @param include_private [Boolean]
    # @return [Boolean]
    def respond_to_missing?(name, include_private = false)
      (body.key?(name.to_s) && !self.class.method_defined?(name)) || super
    end

    private

    # @return [Hash]
    def body
      @data.is_a?(Hash) ? @data : {}
    end
  end
end
