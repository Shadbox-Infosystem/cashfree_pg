# frozen_string_literal: true

require "bigdecimal"
require "json"

module CashfreePg
  # Converts amounts to a two-decimal JSON number.
  #
  # Ruby's JSON library turns a raw BigDecimal into a quoted exponent string
  # such as "0.101e2". {Number} emits `10.10` instead.
  #
  # @api private
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
        value.to_h { |key, item| [key, key.to_s.match?(AMOUNT_KEY) ? number_for(item) : normalize(item)] }
      when Array
        value.map { |item| normalize(item) }
      else
        value
      end
    end

    # @param value [Integer, String, BigDecimal, Float]
    # @return [BigDecimal] rounded half-up to two places
    def coerce(value)
      decimal = case value
                when Integer, BigDecimal then BigDecimal(value)
                when String then decimal_from_string(value)
                when Float then decimal_from_float(value)
                else raise ArgumentError, "amount must be a String, Integer, or BigDecimal"
                end
      raise ArgumentError, "amount is not a number" unless decimal.finite?

      decimal.round(2, BigDecimal::ROUND_HALF_UP)
    end

    # @param decimal [BigDecimal] already rounded to two places
    # @return [String] unquoted JSON number with two decimal places
    def format_number(decimal)
      whole, fraction = decimal.to_s("F").split(".", 2)
      "#{whole}.#{fraction.ljust(2, "0")}"
    end

    def number_for(value)
      value.nil? ? nil : Number.new(coerce(value))
    end

    def decimal_from_string(value)
      BigDecimal(value.strip)
    rescue ArgumentError
      raise ArgumentError, "amount is not a number"
    end

    def decimal_from_float(value)
      warn("CashfreePg received a Float amount; pass a String or BigDecimal", uplevel: 2)
      BigDecimal(value.to_s)
    end
    private_class_method :number_for, :decimal_from_string, :decimal_from_float

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
