# frozen_string_literal: true

RSpec.describe CashfreePg::Money do
  describe ".normalize" do
    it "emits a two-decimal JSON number for BigDecimal, String, and Integer" do
      amounts = {
        order_amount: BigDecimal("10.10"),
        refund_amount: "5.5",
        link_amount: 2
      }
      payload = described_class.normalize(amounts)
      json = JSON.generate(payload)

      expect(json).to include('"order_amount":10.10')
      expect(json).to include('"refund_amount":5.50')
      expect(json).to include('"link_amount":2.00')
      expect(json).not_to include("e2")
      expect(json).not_to include('"10.10"')
    end

    it "leaves non-amount fields unchanged and walks nested hashes and arrays" do
      payload = described_class.normalize(
        {
          order_currency: "INR",
          customer_details: { customer_phone: "9999999999" },
          order_splits: [{ vendor_id: "v1", amount: "1" }],
          order_amount: "1.00"
        }
      )

      expect(payload[:order_currency]).to eq("INR")
      expect(payload[:customer_details][:customer_phone]).to eq("9999999999")
      expect(JSON.generate(payload)).to include('"order_amount":1.00', '"amount":1.00')
    end

    it "rounds half up to two places" do
      expect(JSON.generate(described_class.normalize({ order_amount: "10.005" }))).to eq('{"order_amount":10.01}')
    end

    it "warns on Float and still sends a JSON number" do
      payload = nil
      expect { payload = described_class.normalize({ order_amount: 10.1 }) }
        .to output(/Float/).to_stderr

      expect(JSON.generate(payload)).to include('"order_amount":10.10')
    end

    it "rejects values that are not amounts" do
      expect { described_class.normalize({ order_amount: "abc" }) }
        .to raise_error(ArgumentError, /not a number/)
      expect { described_class.normalize({ order_amount: "Infinity" }) }
        .to raise_error(ArgumentError, /not a number/)
      expect { described_class.normalize({ order_amount: Object.new }) }
        .to raise_error(ArgumentError, /String, Integer, or BigDecimal/)
    end
  end
end
