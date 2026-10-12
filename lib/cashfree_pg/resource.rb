# frozen_string_literal: true

require "uri"

module CashfreePg
  # Base for the API resources on a {Client}.
  class Resource
    # @param client [Client]
    def initialize(client)
      @client = client
    end

    private

    # Wraps each item of a JSON array response so callers get field readers.
    def list_of(response, name)
      items = response.to_h
      unless items.is_a?(Array)
        raise APIError.new("#{name} list was not an array", status: response.status, request_id: response.request_id)
      end

      items.map { |item| Response.new(item, status: response.status, request_id: response.request_id) }
    end

    def order_path(order_id)
      "/orders/#{segment(order_id, "order_id")}"
    end

    # Encodes one path segment. Blank ids and ids containing `/` are rejected
    # so a caller's value cannot change which endpoint is called.
    def segment(id, name)
      text = id.to_s.strip
      raise ArgumentError, "#{name} is required" if text.empty?
      raise ArgumentError, "#{name} must not contain a slash" if text.include?("/")

      URI.encode_uri_component(text)
    end
  end
end
