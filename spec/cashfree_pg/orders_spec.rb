# frozen_string_literal: true

RSpec.describe CashfreePg::Orders do
  let(:client) { build_client }

  it "creates an order and returns the payment session" do
    stub_request(:post, sandbox_url("/orders")).to_return(status: 200, body: fixture("order"))

    response = client.orders.create(
      order_amount: "10.10",
      order_currency: "INR",
      customer_details: { customer_id: "cust_1", customer_phone: "9999999999" }
    )

    expect(a_request(:post, sandbox_url("/orders")).with do |req|
      req.body.include?('"order_amount":10.10') && req.body.include?('"customer_phone":"9999999999"')
    end).to have_been_made
    expect(response.payment_session_id).to eq("session_test_abc")
    expect(response.order_status).to eq("ACTIVE")
    expect(response["order_amount"]).to eq(BigDecimal("10.10"))
  end

  it "sends an idempotency key header, not a body field" do
    stub_request(:post, sandbox_url("/orders")).to_return(status: 200, body: fixture("order"))

    client.orders.create(order_id: "order_123", order_amount: "10.10", order_currency: "INR", idempotency_key: "ord_1")

    expect(a_request(:post, sandbox_url("/orders")).with do |req|
      headers_of(req)["x-idempotency-key"] == "ord_1" && !req.body.include?("idempotency_key")
    end).to have_been_made.once
  end

  it "terminates an order with PATCH" do
    stub_request(:patch, sandbox_url("/orders/order_123"))
      .with(body: '{"order_status":"TERMINATED"}')
      .to_return(status: 200, body: JSON.parse(fixture("order")).merge("order_status" => "TERMINATED").to_json)

    expect(client.orders.terminate("order_123").order_status).to eq("TERMINATED")
  end

  it "fetches an order by id" do
    stub_request(:get, sandbox_url("/orders/order_123")).to_return(status: 200, body: fixture("order"))

    expect(client.orders.fetch("order_123").order_id).to eq("order_123")
  end

  it "maps a duplicate order id to ConflictError" do
    stub_request(:post, sandbox_url("/orders")).to_return(
      status: 409,
      body: { type: "invalid_request_error", code: "order_already_exists", message: "order exists" }.to_json
    )

    expect { client.orders.create(order_id: "order_123", order_amount: "10.10", order_currency: "INR") }
      .to raise_error(CashfreePg::ConflictError, /order_already_exists/)
  end
end
