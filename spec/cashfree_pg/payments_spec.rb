# frozen_string_literal: true

RSpec.describe CashfreePg::Payments do
  let(:client) { build_client }
  let(:order) { CashfreePg::Response.new(JSON.parse(fixture("order")), status: 200, request_id: "req") }
  let(:sessions_url) { sandbox_url("/orders/sessions") }

  def upi_sent
    sent = nil
    expect(a_request(:post, sessions_url).with { |req| sent = JSON.parse(req.body) }).to have_been_made
    sent
  end

  it "lists and fetches payments for an order" do
    stub_request(:get, sandbox_url("/orders/order_123/payments")).to_return(status: 200, body: fixture("payments"))
    stub_request(:get, sandbox_url("/orders/order_123/payments/12376123"))
      .to_return(status: 200, body: JSON.parse(fixture("payments")).first.to_json)

    listed = client.payments.list("order_123")

    expect(listed.map(&:payment_status)).to eq(["SUCCESS"])
    expect(listed.first["payment_amount"]).to eq(BigDecimal("10.10"))
    expect(client.payments.fetch("order_123", "12376123").cf_payment_id).to eq("12376123")
  end

  it "raises APIError when the payments list is not an array" do
    stub_request(:get, sandbox_url("/orders/order_123/payments")).to_return(status: 200, body: "{}")

    expect { client.payments.list("order_123") }.to raise_error(CashfreePg::APIError, /not an array/)
  end

  it "starts a UPI intent on the session without the client secret" do
    stub_request(:post, sessions_url).to_return(status: 200, body: fixture("upi_intent"))

    expect(client.payments.upi(order, channel: :intent).channel).to eq("link")
    expect(a_request(:post, sessions_url).with do |req|
      headers = headers_of(req)
      !headers.key?("x-client-secret") && headers["x-api-version"] == "2025-01-01"
    end).to have_been_made
    expect(upi_sent).to eq(
      "payment_session_id" => "session_test_abc", "payment_method" => { "upi" => { "channel" => "link" } }
    )
  end

  it "maps QR to Cashfree's channel name and accepts a session id string" do
    stub_request(:post, sessions_url).to_return(status: 200, body: "{}")

    client.payments.upi("session_test_abc", channel: :qr)

    expect(upi_sent.dig("payment_method", "upi", "channel")).to eq("qrcode")
  end

  it "sends a collect VPA and passes other UPI options through" do
    stub_request(:post, sessions_url).to_return(status: 200, body: "{}")

    client.payments.upi(order, channel: :collect, upi_id: "testsuccess@gocash", upi_expiry_minutes: 10)

    expect(upi_sent.dig("payment_method", "upi"))
      .to eq("channel" => "collect", "upi_id" => "testsuccess@gocash", "upi_expiry_minutes" => 10)
  end

  it "rejects a bad channel, a missing or malformed VPA, and a missing session" do
    expect { client.payments.upi(order, channel: :nope) }.to raise_error(ArgumentError, /channel/)
    expect { client.payments.upi(order, channel: :collect) }.to raise_error(ArgumentError, /upi_id/)
    expect { client.payments.upi(order, channel: :collect, upi_id: "not a vpa") }
      .to raise_error(ArgumentError, /name@bank/)
    expect { client.payments.upi({}, channel: :intent) }.to raise_error(ArgumentError, /payment_session_id/)
  end

  it "explains S2S when Order Pay returns 403" do
    stub_request(:post, sessions_url).to_return(
      status: 403,
      body: { type: "permission_error", code: "forbidden", message: "not allowed" }.to_json
    )

    expect { client.payments.upi(order, channel: :intent) }
      .to raise_error(CashfreePg::PermissionError, /S2S/) { |e| expect(e.code).to eq("forbidden") }
  end

  it "captures a pre-authorised payment with an idempotency key" do
    url = sandbox_url("/orders/order_123/authorization")
    stub_request(:post, url).to_return(status: 200, body: "{}")

    client.payments.authorize("order_123", action: :capture, amount: "10.10", idempotency_key: "cap_1")

    expect(a_request(:post, url).with do |req|
      req.body == '{"action":"CAPTURE","amount":10.10}' && headers_of(req)["x-idempotency-key"] == "cap_1"
    end).to have_been_made.once
  end

  it "validates the authorization action and amount" do
    expect { client.payments.authorize("order_123", action: :refund) }.to raise_error(ArgumentError, /CAPTURE or VOID/)
    expect { client.payments.authorize("order_123", action: :capture) }.to raise_error(ArgumentError, /amount/)
    expect { client.payments.authorize("order_123", action: :void, amount: "1.00") }
      .to raise_error(ArgumentError, /VOID/)
  end
end
