# frozen_string_literal: true

RSpec.describe CashfreePg::Orders do
  let(:client) { build_client }
  let(:order) { JSON.parse(File.read("spec/fixtures/order.json")) }

  it "creates an order and returns the payment session" do
    stub_request(:post, sandbox_url("/orders")).to_return(status: 200, body: order.to_json)

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

  it "fetches an order by id" do
    stub_request(:get, sandbox_url("/orders/order_123")).to_return(status: 200, body: order.to_json)

    expect(client.orders.fetch("order_123").order_id).to eq("order_123")
  end

  it "maps a duplicate order id to ConflictError" do
    stub_request(:post, sandbox_url("/orders")).to_return(
      status: 409,
      body: { type: "invalid_request_error", code: "order_already_exist", message: "order exists" }.to_json
    )

    expect { client.orders.create(order_id: "order_123", order_amount: "10.10", order_currency: "INR") }
      .to raise_error(CashfreePg::ConflictError, /order_already_exist/)
  end

  it "rejects a blank order id" do
    expect { client.orders.fetch(" ") }.to raise_error(ArgumentError, /order_id/)
  end
end
