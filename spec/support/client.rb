# frozen_string_literal: true

module ClientHelper
  SECRET = "cfsk_test_secret_value"

  def build_client(**)
    CashfreePg::Client.new(
      client_id: "cf_test_id",
      client_secret: SECRET,
      **
    )
  end

  def sandbox_url(path)
    "https://sandbox.cashfree.com/pg#{path}"
  end
end

RSpec.configure do |config|
  config.include ClientHelper
end
