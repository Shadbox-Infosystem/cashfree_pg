# frozen_string_literal: true

require "bigdecimal"
require "json"

module CashfreePg
  # Converts amounts to a two-decimal JSON number.
  #
  # Ruby's JSON library turns a raw BigDecimal into a quoted exponent string
  # such as "0.101e2". {Number} emits `10.10` instead.
  module Money
    AMOUNT_KEY = /(?:\A|_)amount\z/

    module_function

    # Walks a payload and wraps amount fields for JSON.
    #
    # @param value [Object]
    # @return [Object]
    def normalize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), copy|
          copy[key] = amount_key?(key) ? number_for(item) : normalize(item)
        end
      when Array
        value.map { |item| normalize(item) }
      else
        value
      end
    end

    # @param value [Integer, String, BigDecimal, Float]
    # @return [BigDecimal]
    def coerce(value)
      decimal = case value
                when Integer then BigDecimal(value)
                when BigDecimal then value
                when String then decimal_from_string(value)
                when Float then decimal_from_float(value)
                else
                  raise ArgumentError, "amount must be a String, Integer, or BigDecimal"
                end
      decimal.round(2, BigDecimal::ROUND_HALF_UP)
    end

    # @param decimal [BigDecimal]
    # @return [String] unquoted JSON number with two decimal places
    def format_number(decimal)
      text = decimal.to_s("F")
      text = "#{text}.00" unless text.include?(".")
      whole, fraction = text.split(".", 2)
      "#{whole}.#{fraction.ljust(2, "0")[0, 2]}"
    end

    # @param key [String, Symbol]
    # @return [Boolean]
    def amount_key?(key)
      key.to_s.match?(AMOUNT_KEY)
    end

    # @param value [Object]
    # @return [Number, nil]
    def number_for(value)
      return nil if value.nil?

      Number.new(coerce(value))
    end

    # @param value [String]
    # @return [BigDecimal]
    def decimal_from_string(value)
      stripped = value.strip
      raise ArgumentError, "amount is not a number" if stripped.empty?

      BigDecimal(stripped)
    rescue ArgumentError
      raise ArgumentError, "amount is not a number"
    end

    # @param value [Float]
    # @return [BigDecimal]
    def decimal_from_float(value)
      warn("CashfreePg received a Float amount; pass a String or BigDecimal", uplevel: 2)
      BigDecimal(value.to_s)
    end

    # JSON number that does not use exponent notation.
    class Number
      # @param decimal [BigDecimal]
      def initialize(decimal)
        @decimal = decimal
      end

      # @return [String]
      def to_json(*)
        Money.format_number(@decimal)
      end
    end
    private_constant :Number
  end
end
