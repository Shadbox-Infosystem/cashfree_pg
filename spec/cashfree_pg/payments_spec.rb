# frozen_string_literal: true

RSpec.describe CashfreePg::Payments do
  let(:client) { build_client }
  let(:order) { CashfreePg::Response.new(JSON.parse(File.read("spec/fixtures/order.json")), status: 200, request_id: "req") }
  let(:payments) { File.read("spec/fixtures/payments.json") }
  let(:intent) { File.read("spec/fixtures/upi_intent.json") }

  def session_body(request)
    JSON.parse(request.body)
  end

  it "lists payments for an order" do
    stub_request(:get, sandbox_url("/orders/order_123/payments")).to_return(status: 200, body: payments)

    listed = client.payments.list("order_123")

    expect(listed.length).to eq(1)
    expect(listed.first.payment_status).to eq("SUCCESS")
    expect(listed.first["payment_amount"]).to eq(BigDecimal("10.10"))
  end

  it "fetches one payment" do
    stub_request(:get, sandbox_url("/orders/order_123/payments/12376123")).to_return(
      status: 200,
      body: JSON.parse(payments).first.to_json
    )

    expect(client.payments.fetch("order_123", "12376123").cf_payment_id).to eq("12376123")
  end

  it "starts a UPI intent without the client secret" do
    stub_request(:post, sandbox_url("/orders/sessions")).to_return(status: 200, body: intent)

    response = client.payments.upi(order, channel: :intent)

    expect(a_request(:post, sandbox_url("/orders/sessions")).with do |req|
      headers = req.headers.transform_keys(&:downcase)
      body = session_body(req)
      !headers.key?("x-client-secret") &&
        headers["x-api-version"] == "2025-01-01" &&
        body["payment_session_id"] == "session_test_abc" &&
        body.dig("payment_method", "upi", "channel") == "link"
    end).to have_been_made
    expect(response.channel).to eq("link")
  end

  it "starts a UPI QR session" do
    stub_request(:post, sandbox_url("/orders/sessions")).to_return(status: 200, body: intent)

    client.payments.upi("session_test_abc", channel: :qr)

    expect(a_request(:post, sandbox_url("/orders/sessions")).with do |req|
      session_body(req).dig("payment_method", "upi", "channel") == "qrcode"
    end).to have_been_made
  end

  it "sends a collect VPA and accepts Cashfree's sandbox test VPA" do
    stub_request(:post, sandbox_url("/orders/sessions")).to_return(status: 200, body: "{}")

    client.payments.upi(order, channel: :collect, upi_id: "testsuccess@gocash")

    expect(a_request(:post, sandbox_url("/orders/sessions")).with do |req|
      upi = session_body(req).dig("payment_method", "upi")
      upi["channel"] == "collect" && upi["upi_id"] == "testsuccess@gocash"
    end).to have_been_made
  end

  it "requires a VPA for collect and rejects a blank or spaceless-invalid value" do
    expect { client.payments.upi(order, channel: :collect) }.to raise_error(ArgumentError, /upi_id/)
    expect { client.payments.upi(order, channel: :collect, upi_id: "not a vpa") }
      .to raise_error(ArgumentError, /name@bank/)
    expect { client.payments.upi(order, channel: :nope) }.to raise_error(ArgumentError, /channel/)
  end

  it "explains S2S when Order Pay returns 403" do
    stub_request(:post, sandbox_url("/orders/sessions")).to_return(
      status: 403,
      body: { type: "permission_error", code: "forbidden", message: "not allowed" }.to_json
    )

    expect { client.payments.upi(order, channel: :intent) }
      .to raise_error(CashfreePg::PermissionError, /S2S/)
  end

  it "captures a pre-authorised payment with an idempotency key" do
    stub_request(:post, sandbox_url("/orders/order_123/authorization")).to_return(status: 200, body: "{}")

    client.payments.authorize("order_123", action: :capture, amount: "10.10", idempotency_key: "cap_1")

    expect(a_request(:post, sandbox_url("/orders/order_123/authorization")).with do |req|
      body = session_body(req)
      headers = req.headers.transform_keys(&:downcase)
      body["action"] == "CAPTURE" && req.body.include?('"amount":10.10') && headers["x-idempotency-key"] == "cap_1"
    end).to have_been_made.once
  end

  it "does not send an amount when voiding" do
    expect { client.payments.authorize("order_123", action: :void, amount: "1.00") }
      .to raise_error(ArgumentError, /VOID/)
  end
end
